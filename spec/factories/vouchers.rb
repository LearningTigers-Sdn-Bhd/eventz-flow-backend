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
    
    voucher_type { :fixed_amount }
    voucher_value { "9.99" }
  end
end
