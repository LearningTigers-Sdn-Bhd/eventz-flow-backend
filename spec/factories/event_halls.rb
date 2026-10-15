FactoryBot.define do
  factory :event_hall do
    association :event
    sequence(:name) { |n| "Hall #{n}" }
    floor { "Level 1" }
  end
end
