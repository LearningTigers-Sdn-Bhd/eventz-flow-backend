FactoryBot.define do
  factory :group_member do
    association :group
    association :user, factory: :manager_user
    has_manager_access { false }

    trait :manager do
      has_manager_access { true }
      association :user, factory: :manager_user
    end

    trait :member do
      has_manager_access { false }
      association :user, factory: :member_user
    end
  end
end
