FactoryBot.define do
  factory :table_assignment do
    association :ticket
    association :plan_object, factory: [:plan_object, :table]
    notes { nil }
  end
end
