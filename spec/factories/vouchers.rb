FactoryBot.define do
  factory :voucher do
    title { "MyString" }
    description { "MyText" }
    
    # FIX 1: Use FactoryBot associations to automatically create and assign dependencies,
    # satisfying the 'presence: true' validations in the Voucher model.
    # The 'vendor' is defined as a 'User' in the Voucher model via class_name.
    association :vendor, factory: :user 
    # The 'event' is a required association.
    association :event 
    
    voucher_code { "MyString" }
    status { :active } 

    # FIX 2: Use dynamic date/time values to ensure the voucher is usually valid for redemption.
    start_date { Date.current - 1.day }
    end_date { Date.current + 1.day }
    
    # CRITICAL FIX for time validation: 
    # Use explicit Time.zone.parse for consistency with RSpec's Time.use_zone block.
    start_time { Time.zone.parse("00:00:00") } 
    end_time { Time.zone.parse("23:59:59") } 
    
    total_redemption_available { 100 } # More realistic default
    redeemed_count { 0 } # Should start at 0
    max_redemptions_per_user { 5 } # More realistic default
    is_unlimited { false } # Default to limited voucher

    # Trait for unlimited vouchers
    trait :unlimited do
      is_unlimited { true }
      total_redemption_available { nil }
    end

    # Active Storage image - use trait when image is needed
    trait :with_image do
      after(:build) do |voucher|
        voucher.image.attach(
          io: StringIO.new('fake image data'),
          filename: 'voucher_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    voucher_type { :fixed_amount }
    voucher_value { "9.99" }
  end
end
