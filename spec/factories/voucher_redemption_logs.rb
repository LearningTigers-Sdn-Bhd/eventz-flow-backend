FactoryBot.define do
  factory :voucher_redemption_log do
    voucher
    # Use a user as the default redeemer
    association :redeemer, factory: :user
    polymorphic_redeemer_type { 'User' }
    redeemer_type { :user_redeemer }

    redeemer_staff { nil }
    redemption_timestamp { "2025-11-14 10:38:04" }
    redemption_location { nil }
    redemption_status { :completed }
    transaction_gross_amount { "9.99" }
    discount_applied_value { "9.99" }
    transaction_net_amount { "9.99" }
    cancellation_timestamp { "2025-11-14 10:38:04" }
    cancellation_reason { "MyText" }
  end
end
