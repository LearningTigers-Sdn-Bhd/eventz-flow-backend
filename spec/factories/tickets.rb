FactoryBot.define do
  factory :ticket do
    # Associations (use association name if you have default factories for them)
    event
    ticket_type

    # Required Attributes (using Faker or simple defaults)
    attendee_name { "John Doe" }
    attendee_email { "john.doe@example.com" }
    
    # Non-nullable/Default Attributes
    checked_in { false }
    status { :purchased }
    
    # Ensures the public_id is set before validation/save, as per the model's before_create callback.
    # public_id { SecureRandom.uuid } 
    
    # Optional attributes (only used if explicitly passed in the test)
    user { nil }
    order { nil }
    custom_fields_data { {} } 
    
    # A trait for creating an already checked-in ticket for specific tests
    trait :checked_in do
      checked_in { true }
      check_in_at { Time.current }
      status { :scanned }
    end
  end
end