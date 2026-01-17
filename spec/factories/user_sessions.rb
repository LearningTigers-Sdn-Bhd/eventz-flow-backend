FactoryBot.define do
  factory :user_session do
    association :user
    jti { SecureRandom.uuid }
    refresh_token_hash { Digest::SHA256.hexdigest(SecureRandom.hex) }
    expires_at { 30.days.from_now }
    device_name { "Test Device" }
    ip_address { "127.0.0.1" }
    user_agent { "Rails Testing" }
    last_used_at { Time.current }
    revoked { false }

    trait :revoked do
      revoked { true }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
