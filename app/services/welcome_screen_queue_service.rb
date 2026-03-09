class WelcomeScreenQueueService
  DISPLAY_DURATION_MS = 3500
  DISPLAY_DURATION_SECONDS = DISPLAY_DURATION_MS / 1000.0
  MAX_QUEUE_SIZE = 20
  TTL_SECONDS = 120
  DEDUPE_WINDOW_SECONDS = DISPLAY_DURATION_SECONDS
  TABLE_KEY_PRIORITY = %w[tablenumber tableno table].freeze

  class << self
    def enqueue(event_id, name, custom_fields_data: nil)
      return if name.blank?
      
      seating_context = fetch_seating_context(event_id, name)
      table_label = seating_context[:table_label] || extract_table_label(custom_fields_data)

      return if recently_enqueued?(event_id, name, table_label)

      mark_as_enqueued(event_id, name, table_label)
      add_to_queue(event_id, name, table_label, seating_context)
      broadcast_queue_update(event_id)
      schedule_processing(event_id)
    end

    def current_state(event_id)
      active = Rails.cache.read(active_key(event_id))
      size = queue_size(event_id)

      if active.present? && active[:expires_at] > Time.current.to_f
        remaining_ms = [(active[:expires_at] - Time.current.to_f) * 1000, 0].max.to_i
        return {
          type: "state",
          name: active[:name],
          table_label: active[:table_label],
          seating_context: active[:seating_context],
          remaining_ms: remaining_ms,
          queue_size: size
        }
      end

      { type: "state", name: nil, table_label: nil, remaining_ms: 0, queue_size: size }
    end

    def process_next(event_id)
      return if processing_locked?(event_id)

      acquire_lock(event_id)
      process_queue_item(event_id)
    ensure
      release_lock(event_id)
    end

    def queue_size(event_id)
      queue = Rails.cache.read(queue_key(event_id)) || []
      queue.size
    end

    def clear_queue(event_id)
      Rails.cache.delete(queue_key(event_id))
      Rails.cache.delete(active_key(event_id))
    end

    private

    def recently_enqueued?(event_id, name, table_label)
      Rails.cache.read(dedupe_key(event_id, name, table_label)).present?
    end

    def mark_as_enqueued(event_id, name, table_label)
      Rails.cache.write(
        dedupe_key(event_id, name, table_label),
        true,
        expires_in: DEDUPE_WINDOW_SECONDS.seconds
      )
    end

    def add_to_queue(event_id, name, table_label, seating_context = {})
      queue = Rails.cache.read(queue_key(event_id)) || []
      queue << { 
        name: name, 
        table_label: table_label, 
        seating_context: seating_context,
        enqueued_at: Time.current.to_f 
      }
      queue = queue.last(MAX_QUEUE_SIZE)
      Rails.cache.write(queue_key(event_id), queue, expires_in: TTL_SECONDS.seconds)
    end

    def process_queue_item(event_id)
      active = Rails.cache.read(active_key(event_id))

      if active.present? && active[:expires_at] > Time.current.to_f
        remaining = active[:expires_at] - Time.current.to_f
        WelcomeScreenBroadcastJob.set(wait: remaining.seconds).perform_later(event_id)
        return
      end

      entry = fetch_valid_entry(event_id)

      if entry.nil?
        # Wait additional time before clearing so last name displays fully
        WelcomeScreenBroadcastJob.set(wait: DISPLAY_DURATION_SECONDS.seconds).perform_later(event_id) if active.present?
        broadcast_clear(event_id) if active.blank?
        return
      end

      set_active_and_broadcast(event_id, entry)
      WelcomeScreenBroadcastJob.set(wait: DISPLAY_DURATION_SECONDS.seconds).perform_later(event_id)
    end

    def fetch_valid_entry(event_id)
      queue = Rails.cache.read(queue_key(event_id)) || []

      while queue.any?
        entry = queue.shift
        Rails.cache.write(queue_key(event_id), queue, expires_in: TTL_SECONDS.seconds)

        age = Time.current.to_f - entry[:enqueued_at]
        return entry if age <= TTL_SECONDS
      end

      nil
    end

    def set_active_and_broadcast(event_id, entry)
      expires_at = Time.current.to_f + DISPLAY_DURATION_SECONDS

      Rails.cache.write(
        active_key(event_id),
        { 
          name: entry[:name], 
          table_label: entry[:table_label], 
          seating_context: entry[:seating_context],
          expires_at: expires_at 
        },
        expires_in: (DISPLAY_DURATION_SECONDS + 1).seconds
      )

      ActionCable.server.broadcast(
        "welcome_screen_event_#{event_id}",
        {
          type: "display",
          name: entry[:name],
          table_label: entry[:table_label],
          seating_context: entry[:seating_context],
          display_duration_ms: DISPLAY_DURATION_MS,
          checked_in_at: Time.current.iso8601
        }
      )

      broadcast_queue_update(event_id)
    end

    def schedule_processing(event_id)
      active = Rails.cache.read(active_key(event_id))
      WelcomeScreenBroadcastJob.perform_later(event_id) if active.blank?
    end

    def broadcast_queue_update(event_id)
      ActionCable.server.broadcast(
        "welcome_screen_event_#{event_id}",
        { type: "queue_update", queue_size: queue_size(event_id) }
      )
    end

    def broadcast_clear(event_id)
      ActionCable.server.broadcast(
        "welcome_screen_event_#{event_id}",
        { type: "clear" }
      )
    end

    def fetch_seating_context(event_id, name)
      normalized_name = name.to_s.strip.downcase
      event = Event.find(event_id)
      display_settings = event.check_in_display
      
      # Use active_plan_id if set, otherwise we don't have a context for specific sessions
      active_plan_id = display_settings&.active_plan_id
      return {} if active_plan_id.nil?

      # Find the attendee
      participant = event.tickets.where("LOWER(attendee_name) = ?", normalized_name).first ||
                    event.visitors.where("LOWER(full_name) = ?", normalized_name).first
      
      return {} if participant.nil?

      # Find assignment SPECIFIC to the active plan
      assignment = participant.table_assignments.joins(:plan_object)
                              .where(plan_objects: { plan_id: active_plan_id })
                              .first
      
      return {} if assignment.nil?

      # Mark this specific assignment as arrived for this session
      assignment.update(arrived_at: Time.current) if assignment.arrived_at.nil?

      table = assignment.plan_object
      plan = table.plan

      # Get all guests at this table
      table_guests = table.table_assignments.includes(:ticket, :visitor).map do |asgn|
        guest = asgn.ticket || asgn.visitor
        {
          name: guest.respond_to?(:attendee_name) ? guest.attendee_name : guest.full_name,
          # Use arrived_at for this session instead of global checked_in
          is_checked_in: asgn.arrived_at.present?
        }
      end

      {
        plan_id: plan.id,
        table_id: table.id,
        table_label: table.label || "Meja #{table.id}",
        table_guests: table_guests
      }
    end

    def processing_locked?(event_id)
      Rails.cache.read(lock_key(event_id)).present?
    end

    def acquire_lock(event_id)
      Rails.cache.write(lock_key(event_id), true, expires_in: 5.seconds)
    end

    def release_lock(event_id)
      Rails.cache.delete(lock_key(event_id))
    end

    def queue_key(event_id)
      "welcome_queue:#{event_id}"
    end

    def active_key(event_id)
      "welcome_active:#{event_id}"
    end

    def lock_key(event_id)
      "welcome_lock:#{event_id}"
    end

    def dedupe_key(event_id, name, table_label)
      dedupe_value = [name, table_label].join("|").downcase.strip
      "welcome_dedupe:#{event_id}:#{Digest::MD5.hexdigest(dedupe_value)}"
    end

    def extract_table_label(custom_fields_data)
      return nil unless custom_fields_data.is_a?(Hash)

      normalized_entries = custom_fields_data.each_with_object({}) do |(key, value), hash|
        normalized_key = normalize_table_key(key)
        next if normalized_key.blank?

        hash[normalized_key] = value
      end

      raw_value = nil

      TABLE_KEY_PRIORITY.each do |priority_key|
        value = normalized_entries[priority_key]
        next if value.blank?

        raw_value = value
        break
      end

      if raw_value.blank?
        raw_value = normalized_entries.find { |key, value| key.include?("table") && value.present? }&.last
      end

      format_table_label(raw_value)
    end

    def normalize_table_key(key)
      key.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def format_table_label(raw_value)
      value = raw_value.to_s.strip
      return nil if value.blank?
      return value if value.match?(/\Ameja\b/i)
      return value.sub(/\Atable\b/i, 'Meja') if value.match?(/\Atable\b/i)

      "Meja #{value}"
    end
  end
end
