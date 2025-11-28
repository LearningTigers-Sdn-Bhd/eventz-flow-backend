FactoryBot.define do
  factory :event_exhibition_contractor do
    association :event
    association :exhibition_contractor_profile
  end
end
