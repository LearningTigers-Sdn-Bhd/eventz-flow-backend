FactoryBot.define do
  factory :group do
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }

    trait :with_manager do
      after(:create) do |group|
        manager = create(:user, :organizer)
        create(:group_member, group: group, user: manager, has_manager_access: true)
      end
    end

    trait :with_vendor do
      after(:create) do |group|
        vendor = create(:user, :vendor)
        create(:group_affiliate, group: group, vendor: vendor)
      end
    end
  end
end
