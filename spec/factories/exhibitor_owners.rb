# spec/factories/exhibitor_owners.rb

FactoryBot.define do
  factory :exhibitor_owner do
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    contact_email { Faker::Internet.email }
    contact_phone { Faker::PhoneNumber.phone_number }
  end
end
