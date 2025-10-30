FactoryBot.define do
  factory :event_location do
    association :event
    name { Faker::Address.street_address }
    scan_limit { 100 }

    trait :unlimited do
      is_unlimited { true }
      scan_limit { 0 }
    end
  end
end
