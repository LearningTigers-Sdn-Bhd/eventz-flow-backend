class TicketGroupSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :position, :priority_ticket_type_ids

  # counts: { ticket_group_id => paid tickets in it }
  attribute :ticket_count do |group, params|
    params[:counts][group.id] || 0
  end

  # Flat rows for the panel, which does not use the JSON:API envelope.
  def self.rows(groups, counts)
    new(groups, params: { counts: counts }).serializable_hash[:data].map { |row| row[:attributes] }
  end
end
