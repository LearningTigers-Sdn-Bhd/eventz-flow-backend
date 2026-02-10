FactoryBot.define do
  factory :event_seat_group do
    association :event_seat_section
    name { "Premium Group" }
    extra_price { 50.0 }
  end
end
