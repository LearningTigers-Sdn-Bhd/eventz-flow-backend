# spec/factories/refresh_tokens.rb

# Ensure you have 'authentication_service.rb' loaded for factories to use
# The FactoryBot setup will typically handle loading app files, but if you hit errors, 
# ensure the service is loaded here:
# require Rails.root.join('app/services/authentication_service')

FactoryBot.define do
  factory :refresh_token do
    association :user

    # Transient attribute to allow passing the raw token string in tests
    # This simulates the raw token that would be set in the HTTP-only cookie
    transient do
      # Use the secure generator to create the raw token
      raw_token { AuthenticationService.generate_secure_token }
    end
    
    # Hash the raw token for persistence in the database
    token_hash { AuthenticationService.hash_token(raw_token) }
    
    # Set standard expiry
    expires_at { 7.days.from_now }
    revoked_at { nil } 

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.minute.ago }
    end

    trait :active do
      expires_at { 7.days.from_now }
      revoked_at { nil }
    end
  end
end