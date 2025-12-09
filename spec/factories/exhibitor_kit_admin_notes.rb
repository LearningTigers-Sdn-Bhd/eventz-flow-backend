FactoryBot.define do
  factory :exhibitor_kit_admin_note do
    association :exhibitor_kit
    association :user
    note { Faker::Lorem.paragraph }
  end
end
