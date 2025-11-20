FactoryBot.define do
  factory :voucher_usage do
    voucher { nil }
    association :redeemer, factory: :user
    redemption_count { 1 }
    first_view_timestamp { "2025-11-14 10:38:13" }

    trait :for_user do
      association :redeemer, factory: :user
    end

    trait :for_visitor do
      association :redeemer, factory: :visitor
    end
  end
end
