FactoryBot.define do
  factory :exhibitor_registration_payment do
    exhibitor_kit
    amount { 1500.00 }
    status { "pending" }
    gateway { "razorpay" }
  end
end
