FactoryBot.define do
  factory :event_location_member do
    association :event_location
    association :member, factory: :member_user
  end
end

