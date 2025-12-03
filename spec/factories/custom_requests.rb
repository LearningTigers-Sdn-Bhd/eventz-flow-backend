FactoryBot.define do
  factory :custom_request do
    association :exhibitor_kit
    description { Faker::Lorem.sentence }
    quantity { Faker::Number.between(from: 1, to: 5) }
    status { :pending }
    resolved_price { nil }
    response_notes { nil }
  end
end
