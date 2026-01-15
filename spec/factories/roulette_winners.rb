FactoryBot.define do
  factory :roulette_winner do
    association :roulette_session
    association :roulette_prize
    drawn_at { Time.current }

    trait :with_ticket do
      association :ticket
    end

    trait :with_visitor do
      association :visitor
    end
  end
end
