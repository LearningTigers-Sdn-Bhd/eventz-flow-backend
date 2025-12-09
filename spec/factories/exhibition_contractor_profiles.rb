FactoryBot.define do
  factory :exhibition_contractor_profile do
    association :user, :exhibition_contractor, with_profile: false
    company_name { Faker::Company.name }
    contact_person { Faker::Name.name }
    contact_email { Faker::Internet.email }
    contact_phone { Faker::PhoneNumber.phone_number }
  end
end