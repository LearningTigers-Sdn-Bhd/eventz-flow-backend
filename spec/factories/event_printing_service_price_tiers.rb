FactoryBot.define do
  factory :event_printing_service_price_tier do
    association :event_printing_service
    price { Faker::Commerce.price(range: 5.0..500.0) }
    start_date { Faker::Date.backward(days: 30) }
    end_date { Faker::Date.forward(days: 30) }
    label { Faker::Lorem.word }
  end
end
