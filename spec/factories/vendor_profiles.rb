# spec/factories/vendor_profiles.rb

FactoryBot.define do
  factory :vendor_profile do
    association :group
    association :vendor, factory: :user
    vendor_name { 'Vendor Name' }
    vendor_description { 'Vendor description' }
    image_path { nil }
    manager_id { nil }
  end
end
