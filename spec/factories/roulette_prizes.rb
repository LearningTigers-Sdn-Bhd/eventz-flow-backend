FactoryBot.define do
  factory :roulette_prize do
    association :roulette_session
    name { "Grand Prize" }
    quantity { 3 }
  end
end
