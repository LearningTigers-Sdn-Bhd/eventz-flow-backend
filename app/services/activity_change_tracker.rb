# frozen_string_literal: true

# Computes a before/after diff for a small set of tracked fields on an
# update action, so the activity log can show "Ticket Type: General -> VIP"
# instead of a raw param dump. Only fields registered below get a diff;
# everything else keeps falling back to the existing sanitized-params blob.
#
# UserActivityRecorder runs in a before_action (see authenticable.rb), so the
# record fetched here is still in its PRE-update state — safe to compare
# directly against the just-submitted params.
class ActivityChangeTracker
  Field = Struct.new(:param_paths, :label, :cast, :kind, keyword_init: true)

  REGISTRY = {
    'v1/tickets' => {
      # with_deleted: restore/cancel_ticket target a ticket that may already
      # be soft-deleted at this point, which the default scope would hide.
      finder: ->(params) { Ticket.with_deleted.find_by(public_id: params[:id]) },
      fields: {
        ticket_type_id: Field.new(param_paths: [%i[ticket ticket_type_id]], label: 'Ticket Type'),
        payment_status: Field.new(param_paths: [%i[ticket payment_status]], label: 'Payment Status', cast: :before_type_cast),
        attendee_name: Field.new(param_paths: [%i[ticket attendee_name]], label: 'Attendee Name'),
        attendee_email: Field.new(param_paths: [%i[ticket attendee_email]], label: 'Attendee Email'),
        attendee_phone: Field.new(param_paths: [%i[ticket attendee_phone]], label: 'Attendee Phone'),
        role: Field.new(param_paths: [%i[ticket role]], label: 'Role'),
        # custom_fields_data is a per-event, organizer-defined jsonb blob (keys
        # vary per event) — diffed key-by-key instead of as one opaque value.
        custom_fields_data: Field.new(param_paths: [%i[ticket custom_fields_data]], label: 'Custom Field', kind: :hash)
      },
      # Actions with no submitted params to diff against — the state change is
      # implied by the action itself, not by anything in the request body.
      action_effects: {
        'destroy' => ->(_record) { { 'Status' => { from: 'Active', to: 'Archived' } } },
        'restore' => ->(_record) { { 'Status' => { from: 'Archived', to: 'Active' } } },
        'force_delete' => ->(_record) { { 'Status' => { from: 'Active', to: 'Permanently Deleted' } } },
        'cancel_ticket' => ->(record) { { 'Status' => { from: record.status.to_s.humanize, to: 'Canceled' } } }
      }
    },
    'v1/events' => {
      finder: ->(params) { Event.with_deleted.find_by(id: params[:id]) },
      fields: {
        status: Field.new(param_paths: [%i[event status], [:status]], label: 'Status')
      }
    }
  }.freeze

  # Returns { "Field Label" => { "from" => "...", "to" => "..." } } describing
  # what changed. Empty hash when the controller/action isn't registered or
  # nothing changed.
  def self.call(controller:, action:, params:)
    entry = REGISTRY[controller]
    return {} unless entry

    record = entry[:finder].call(params)
    return {} unless record

    return diff_fields(record, entry[:fields], params) if action == 'update' && entry[:fields]

    effect = entry[:action_effects]&.dig(action)
    return {} unless effect

    effect.call(record)
  rescue StandardError => e
    Rails.logger.warn("ActivityChangeTracker failed: #{e.message}")
    {}
  end

  def self.diff_fields(record, fields, params)
    fields.each_with_object({}) do |(attr, field), changes|
      submitted = field.param_paths.filter_map { |path| params.dig(*path) }.first
      next if submitted.blank?

      if field.kind == :hash
        diff_hash_field(record, attr, field, submitted, changes)
        next
      end

      current = record.public_send(attr)
      # Some attrs (e.g. enums) can be submitted either as their cast name or
      # their raw stored value — accept either as "unchanged".
      accepted = [current.to_s]
      accepted << record.public_send("#{attr}_#{field.cast}").to_s if field.cast
      next if accepted.include?(submitted.to_s)

      changes[field.label] = { from: current.to_s, to: humanize_value(record.class, attr, submitted) }
    end
  end

  # Organizer-defined custom fields are stored as one jsonb blob with
  # per-event keys, so there's no fixed field list to register — diff each
  # submitted key against the record's current value for that key instead.
  def self.diff_hash_field(record, attr, field, submitted, changes)
    current = record.public_send(attr) || {}
    submitted_hash = submitted.respond_to?(:to_unsafe_h) ? submitted.to_unsafe_h : submitted.to_h

    submitted_hash.first(12).each do |key, new_value|
      old_value = current[key.to_s] || current[key.to_sym]
      next if old_value.to_s == new_value.to_s

      changes["#{field.label}: #{key.to_s.humanize}"] = { from: old_value.to_s, to: new_value.to_s }
    end
  end

  # A submitted enum value can arrive as its raw stored value (e.g. "0")
  # instead of its cast name (e.g. "pending") — resolve it back to the name
  # so the diff reads the same way regardless of what the client sent.
  def self.humanize_value(klass, attr, value)
    enum_map = klass.respond_to?(:defined_enums) ? klass.defined_enums[attr.to_s] : nil
    return value.to_s if enum_map.blank? || enum_map.key?(value.to_s)

    enum_map.key(value.to_i) || value.to_s
  end
end
