# Manually-triggered reconciliation that reads a ticket-side custom field
# (set via bulk import or manual edit - defaults to `table_number`) and
# assigns/moves the ticket to the matching table in this plan. This is the
# reverse of TableAssignment#sync_ticket_table_number, which writes the
# reserved `_table_number` field FROM an existing assignment.
class TableNumberSyncService
  DEFAULT_CUSTOM_FIELD_KEY = 'table_number'.freeze

  # Recommends which of the event's custom fields most likely holds the
  # table number, so the frontend can pre-select it. Falls back to the
  # conventional `table_number` key, then nil if nothing looks like a match.
  def self.recommend_field_key(labels_data)
    keys = labels_data.to_h.keys
    return DEFAULT_CUSTOM_FIELD_KEY if keys.include?(DEFAULT_CUSTOM_FIELD_KEY)

    keys.find { |key| key.match?(/table.?(no|num|number)/i) }
  end

  def initialize(plan, field_key: nil)
    @plan = plan
    @field_key = field_key.presence || DEFAULT_CUSTOM_FIELD_KEY
    @tables_by_number = plan.plan_objects.object_type_table
                            .where.not(table_number: [nil, ''])
                            .index_by { |table| normalize(table.table_number) }
    @warnings = []
  end

  def call
    synced_count = 0

    tickets_with_table_number.find_each do |ticket|
      value = ticket.custom_fields_data[@field_key].to_s.strip
      table = @tables_by_number[normalize(value)]

      unless table
        add_warning(ticket, value, 'no_matching_table')
        next
      end

      if sync_assignment(ticket, table)
        synced_count += 1
      else
        add_warning(ticket, value, @last_error)
      end
    end

    { synced_count: synced_count, warnings: @warnings, field_key: @field_key }
  end

  private

  def tickets_with_table_number
    @plan.event.tickets.active.where(
      "custom_fields_data ->> :key IS NOT NULL AND custom_fields_data ->> :key != ''", key: @field_key
    )
  end

  # Returns true if the ticket ends up correctly assigned to `table` in this
  # plan (whether it was already there, moved, or newly created).
  def sync_assignment(ticket, table)
    assignment = ticket.table_assignments.joins(:plan_object)
                        .find_by(plan_objects: { plan_id: @plan.id })

    return true if assignment&.plan_object_id == table.id

    assignment ||= ticket.table_assignments.build
    assignment.plan_object = table

    if assignment.save
      true
    else
      @last_error = assignment.errors.full_messages.to_sentence.presence || 'could_not_assign'
      false
    end
  end

  def add_warning(ticket, value, reason)
    @warnings << {
      ticket_id: ticket.id,
      attendee_name: ticket.attendee_name,
      table_number: value,
      reason: reason
    }
  end

  def normalize(value)
    value.to_s.strip.downcase
  end
end
