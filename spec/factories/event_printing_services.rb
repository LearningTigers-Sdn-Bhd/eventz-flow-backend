FactoryBot.define do
  factory :event_printing_service do
    association :event
    association :printing_service
  end
end
