FactoryBot.define do
  factory :exhibitor_kit_item do
    association :exhibitor_kit
    association :rentable_item
    quantity { Faker::Number.between(from: 1, to: 10) }
    agreed_price { Faker::Commerce.price(range: 10.0..1000.0) }
    notes { Faker::Lorem.sentence }
  end
end
