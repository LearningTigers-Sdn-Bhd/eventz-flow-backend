class TicketTypePriceTierSerializer
  include JSONAPI::Serializer

  attributes :id, :label, :price, :starts_at, :ends_at

  attribute :active do |tier|
    tier.active?
  end
end
