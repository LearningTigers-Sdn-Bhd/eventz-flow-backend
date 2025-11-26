FactoryBot.define do
  factory :exhibitor_team_member do
    association :exhibitor_kit
    full_name { Faker::Name.name }
  end
end
