# spec/factories/vendor_profiles.rb

FactoryBot.define do
  factory :vendor_profile do
    association :vendor, factory: :user, role: :vendor
    description { 'Vendor description' }
    image_path { nil }
    category { 'Technology' }
    person_in_charge { 'John Doe' }
    address { '123 Main St, City, Country' }
    notes { 'Additional notes' }
  end
end
