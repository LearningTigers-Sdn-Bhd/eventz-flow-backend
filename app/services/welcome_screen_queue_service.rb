class WelcomeScreenQueueService
  DISPLAY_DURATION_MS = 3500
  DISPLAY_DURATION_SECONDS = DISPLAY_DURATION_MS / 1000.0
  MAX_QUEUE_SIZE = 20
  TTL_SECONDS = 120
  DEDUPE_WINDOW_SECONDS = 10

  class << self
    def enqueue(event_id, name)
      return if name.blank?
      return if recently_enqueued?(event_id, name)

      mark_as_enqueued(event_id, name)
      add_to_queue(event_id, name)
      broadcast_queue_update(event_id)
      schedule_processing(event_id)
    end

    def current_state(event_id)
      active = Rails.cache.read(active_key(event_id))
      size = queue_size(event_id)

      if active.present? && active[:expires_at] > Time.current.to_f
        remaining_ms = [(active[:expires_at] - Time.current.to_f) * 1000, 0].max.to_i
        return { type: "state", name: active[:name], remaining_ms: remaining_ms, queue_size: size }
      end

      { type: "state", name: nil, remaining_ms: 0, queue_size: size }
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

    def recently_enqueued?(event_id, name)
      Rails.cache.read(dedupe_key(event_id, name)).present?
    end

    def mark_as_enqueued(event_id, name)
      Rails.cache.write(dedupe_key(event_id, name), true, expires_in: DEDUPE_WINDOW_SECONDS.seconds)
    end

    def add_to_queue(event_id, name)
      queue = Rails.cache.read(queue_key(event_id)) || []
      queue << { name: name, enqueued_at: Time.current.to_f }
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
        { name: entry[:name], expires_at: expires_at },
        expires_in: (DISPLAY_DURATION_SECONDS + 1).seconds
      )

      ActionCable.server.broadcast(
        "welcome_screen_event_#{event_id}",
        { type: "display", name: entry[:name], display_duration_ms: DISPLAY_DURATION_MS, checked_in_at: Time.current.iso8601 }
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

    def dedupe_key(event_id, name)
      "welcome_dedupe:#{event_id}:#{Digest::MD5.hexdigest(name.to_s.downcase.strip)}"
    end
  end
end
