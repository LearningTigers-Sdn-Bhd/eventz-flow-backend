FactoryBot.define do
  factory :cloned_voice do
    association :owner, factory: :user
    association :creator, factory: :user
    name { Faker::Name.name }
    status { :pending }
    settings do
      {
        stability: 0.5,
        similarity_boost: 0.75,
        style: 0.0,
        use_speaker_boost: true
      }
    end

    trait :ready do
      status { :ready }
      elevenlabs_id { "elevenlabs_#{SecureRandom.hex(10)}" }
    end

    trait :failed do
      status { :failed }
    end

    trait :with_event do
      association :event
    end
  end
end
