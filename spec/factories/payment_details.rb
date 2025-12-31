FactoryBot.define do
  factory :payment_detail do
    association :user
    bank_name { Faker::Bank.name }
    account_number { Faker::Bank.account_number(digits: 10) }
    account_name { Faker::Name.name }
  end
end
