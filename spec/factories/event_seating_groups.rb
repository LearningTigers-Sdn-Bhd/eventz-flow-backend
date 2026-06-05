FactoryBot.define do
  factory :event_seating_group do
    association :event
    plan { association(:plan, event: event) }
    scope { :plan_only }
    name { "Family Group" }
    notes { "Keep together" }

    trait :event_level do
      scope { :event_level }
      plan { nil }
    end
  end
end
