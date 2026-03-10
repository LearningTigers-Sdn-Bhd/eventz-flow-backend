FactoryBot.define do
  factory :event_ticket_seat do
    association :event_seat_section
    sequence(:name) { |n| "Seat #{n}" }
    extra_price { 0.0 }
    sequence(:row_set) { |n| n }
    sequence(:col_set) { |n| n }
    ticket { nil }
  end
end
