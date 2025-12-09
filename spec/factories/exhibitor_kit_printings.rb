FactoryBot.define do
  factory :exhibitor_kit_printing do
    association :exhibitor_kit
    association :printing_service
    quantity { Faker::Number.between(from: 1, to: 10) }
    agreed_price { Faker::Commerce.price(range: 5.0..500.0) }
    file_reference { Faker::Internet.url }
    notes { Faker::Lorem.sentence }
  end
end
