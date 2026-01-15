FactoryBot.define do
  factory :roulette_assign do
    association :roulette_session
    association :user
  end
end
