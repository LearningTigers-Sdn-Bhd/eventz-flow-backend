FactoryBot.define do
  factory :ticket do
    # Associations (use association name if you have default factories for them)
    event
    ticket_type

    # Required Attributes (using Faker or simple defaults)
    attendee_name { "John Doe" }
    attendee_email { "john.doe@example.com" }
    attendee_phone { "+1234567890" }
    role { "General" }
    
    # Non-nullable/Default Attributes
    checked_in { false }
    status { :purchased }
    payment_status { :pending }
    
    # Ensures the public_id is set before validation/save, as per the model's before_create callback.
    # public_id { SecureRandom.uuid } 
    
    # Optional attributes (only used if explicitly passed in the test)
    # user { nil }
    # order { nil }
    custom_fields_data { {} } 

    association :user, factory: :user
    
    # A trait for creating an already checked-in ticket for specific tests
    trait :checked_in do
      checked_in { true }
      check_in_at { Time.current }
      status { :scanned }
    end

    # A trait for creating a paid ticket for specific tests
    trait :paid do
      payment_status { :paid }
      transaction_id { SecureRandom.hex(10) }
      payment_method { 'credit_card' }
    end

    # A trait for creating a ticket with payment screenshot
    trait :with_payment_screenshot do
      payment_screenshot_url { 'https://example.com/screenshots/payment123.jpg' }
    end
  end
end