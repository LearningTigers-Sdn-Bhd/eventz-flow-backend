FactoryBot.define do
  factory :event_seat_session do
    association :event
    name { Faker::Lorem.word }
    location { Faker::Address.street_name }
    start_datetime { Time.current + 1.day }
    end_datetime { Time.current + 2.days }
  end
end
