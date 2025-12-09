FactoryBot.define do
  factory :event_rentable_item do
    association :event
    association :rentable_item
  end
end
