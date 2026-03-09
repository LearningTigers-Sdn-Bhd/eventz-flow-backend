FactoryBot.define do
  factory :event_seating_group_member do
    association :event_seating_group
    association :participant, factory: :ticket
  end
end
