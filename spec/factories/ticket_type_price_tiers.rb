FactoryBot.define do
  factory :ticket_type_price_tier do
    ticket_type
    label { "Early Bird" }
    price { 100.00 }
    starts_at { 1.day.from_now }
    ends_at { 30.days.from_now }
  end
end
