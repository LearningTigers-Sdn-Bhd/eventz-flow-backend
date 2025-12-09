FactoryBot.define do
  factory :printing_service do
    association :item_category
    association :user
    name { "Printing Service #{Faker::Number.unique.number(digits: 3)}" }
    description { Faker::Lorem.paragraph }
    unit_of_measure { %w[unit page sheet].sample }
    default_price { Faker::Commerce.price(range: 5.0..500.0) }
    status { :active }
  end
end
