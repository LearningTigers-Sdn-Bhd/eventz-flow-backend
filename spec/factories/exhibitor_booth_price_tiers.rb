FactoryBot.define do
  factory :exhibitor_booth_price_tier do
    association :exhibitor_booth_price
    price { Faker::Commerce.price(range: 10.0..5000.0) }
    start_date { 1.day.ago }
    end_date { 1.day.from_now }
    sequence(:label) { |n| "Booth Tier #{n}" }
  end
end
