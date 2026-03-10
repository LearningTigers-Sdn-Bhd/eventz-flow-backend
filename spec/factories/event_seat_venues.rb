FactoryBot.define do
  factory :event_seat_venue do
    association :event_seat_session
    name { "Main Venue" }
    total_row { 10 }
    total_column { 12 }
  end
end
