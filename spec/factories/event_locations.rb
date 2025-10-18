FactoryBot.define do
  factory :event_location do
    association :event
    name { Faker::Address.street_address }
    scan_limit { 100 }
  end
end