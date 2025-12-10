# spec/factories/gift_winners.rb

FactoryBot.define do
  factory :gift_winner do
    association :gift
    association :visitor
    drawn_at { Time.current }

    trait :with_ticket do
      visitor { nil }
      association :ticket
    end
  end
end
