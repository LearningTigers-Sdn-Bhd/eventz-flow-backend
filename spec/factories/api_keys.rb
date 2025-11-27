FactoryBot.define do
  factory :api_key do
    association :user
    raw_key { SecureRandom.hex(32) }
  end
end
