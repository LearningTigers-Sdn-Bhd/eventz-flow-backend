FactoryBot.define do
  factory :gift do
    association :lucky_draw_session
    name { Faker::Commerce.product_name }
    order { 1 }
    winner_counts { 1 } # Must be > 0
  end
end