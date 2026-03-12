FactoryBot.define do
  factory :exhibitor_team_member do
    association :exhibitor_kit
    full_name { Faker::Name.name }
    email { Faker::Internet.email }
    phone { '+60123456789' }
  end
end
