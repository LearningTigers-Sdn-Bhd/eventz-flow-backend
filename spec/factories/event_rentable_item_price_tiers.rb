FactoryBot.define do
  factory :event_rentable_item_price_tier do
    association :event_rentable_item
    price { Faker::Commerce.price(range: 10.0..1000.0) }
    start_date { Faker::Date.backward(days: 30) }
    end_date { Faker::Date.forward(days: 30) }
    label { Faker::Lorem.word }
  end
end
