FactoryBot.define do
  factory :event_ticket_seat do
    association :event_seat_section
    name { "Seat A1" }
    extra_price { 0.0 }
    row_set { 1 }
    col_set { 1 }
    ticket { nil }
  end
end
