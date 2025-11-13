# spec/factories/visitors.rb

FactoryBot.define do
  factory :visitor do
    association :event
    public_id { SecureRandom.uuid }
    full_name { Faker::Name.name }
    gender { 'male' }
    age { 30 }
    phone { '+1234567890' }
    email { Faker::Internet.email }
  end
end
