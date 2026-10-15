FactoryBot.define do
  factory :booth_plan do
    event
    sequence(:name) { |n| "Booth Plan #{n}" }
    position { 0 }
    active { true }
  end
end
