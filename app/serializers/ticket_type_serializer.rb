class TicketTypeSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :price, :quantity, :max_per_order, :status, :hidden,
             :sale_starts_at, :sale_ends_at, :created_at, :updated_at

  attribute :current_price do |ticket_type|
    ticket_type.current_price
  end

  attribute :current_tier do |ticket_type|
    tier = ticket_type.active_tier
    if tier
      {
        id: tier.id,
        label: tier.label,
        price: tier.price,
        ends_at: tier.ends_at
      }
    end
  end

  attribute :price_tiers do |ticket_type|
    ticket_type.ticket_type_price_tiers.ordered.map do |tier|
      {
        id: tier.id,
        label: tier.label,
        price: tier.price,
        starts_at: tier.starts_at,
        ends_at: tier.ends_at,
        active: tier.active?
      }
    end
  end
end
