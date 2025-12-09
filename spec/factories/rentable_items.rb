FactoryBot.define do
  factory :rentable_item do
    association :item_category
    association :user
    name { "Rentable Item #{Faker::Number.unique.number(digits: 3)}" }
    description { Faker::Lorem.paragraph }
    unit_of_measure { %w[unit day hour].sample }
    default_price { Faker::Commerce.price(range: 10.0..1000.0) }
    status { :active }
  end
end
