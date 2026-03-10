FactoryBot.define do
  factory :event_seat_section do
    association :event_seat_venue
    name { "Section A" }
    price { 0.0 }
    start_row { 1 }
    start_column { 1 }
    seat_row { 1 }
    seat_column { 1 }
    row_span { 1 }
    col_span { 1 }
  end
end
