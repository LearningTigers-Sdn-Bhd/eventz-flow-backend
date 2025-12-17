# spec/factories/vendor_profiles.rb

FactoryBot.define do
  factory :vendor_profile do
    association :vendor, factory: :user, role: :vendor
    description { 'Vendor description' }
    category { 'Technology' }
    person_in_charge { 'John Doe' }
    address { '123 Main St, City, Country' }
    notes { 'Additional notes' }

    # Active Storage image - use trait when image is needed
    trait :with_image do
      after(:build) do |profile|
        profile.image.attach(
          io: StringIO.new('fake image data'),
          filename: 'vendor_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
