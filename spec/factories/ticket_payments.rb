FactoryBot.define do
  factory :ticket_payment do
    ticket
    amount { 100.00 }
    currency { "MYR" }
    status { "pending" }

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
    end

    trait :cash do
      payment_method { "cash" }
      status { "paid" }
      paid_at { Time.current }
    end

    trait :online do
      gateway { "razorpay" }
      gateway_payment_id { "pay_#{SecureRandom.hex(8)}" }
    end
  end
end
