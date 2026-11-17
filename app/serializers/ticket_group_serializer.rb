class TicketGroupSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :position, :priority_ticket_type_ids

  # counts: { ticket_group_id => paid tickets in it }
  attribute :ticket_count do |group, params|
    params[:counts][group.id] || 0
  end

  # { ticket_type_id => paid tickets of that type in the group }
  attribute :type_counts do |group, params|
    params[:by_type][group.id] || {}
  end

  # Flat rows for the panel, which does not use the JSON:API envelope.
  # by_type: { ticket_group_id => { ticket_type_id => n } }
  def self.rows(groups, counts, by_type = {})
    new(groups, params: { counts: counts, by_type: by_type }).serializable_hash[:data].map { |row| row[:attributes] }
  end
end
