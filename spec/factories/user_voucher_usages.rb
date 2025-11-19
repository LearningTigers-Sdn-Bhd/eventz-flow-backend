FactoryBot.define do
  factory :user_voucher_usage do
    voucher { nil }
    user { nil }
    redemption_count { 1 }
    first_view_timestamp { "2025-11-14 10:38:13" }
  end
end
