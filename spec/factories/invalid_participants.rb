FactoryBot.define do
  factory :invalid_participant do
    association :lucky_draw_session
    association :visitor

    trait :with_ticket do
      visitor { nil }
      association :ticket
    end
  end
end