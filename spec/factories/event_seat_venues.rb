FactoryBot.define do
  factory :event_seat_venue do
    association :event_seat_session
    name { "Main Venue" }
    row { 10 }
    column { 12 }
  end
end
