FactoryBot.define do
  factory :group_affiliate do
    association :group
    association :vendor, factory: :vendor_user
  end
end
