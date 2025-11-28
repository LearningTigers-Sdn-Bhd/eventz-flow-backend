FactoryBot.define do
  factory :exhibition_contractor_profile do
    association :user, factory: :exhibition_contractor_user
    company_name { Faker::Company.name }
    contact_person { Faker::Name.name }
    contact_email { Faker::Internet.email }
    contact_phone { Faker::PhoneNumber.phone_number }
  end

  factory :exhibition_contractor_user, parent: :user do
    role { :exhibition_contractor }
  end
end