# spec/factories/wishes.rb
FactoryBot.define do
  factory :wish do
    association :event
    guest_name { Faker::Name.name }
    message { Faker::Lorem.sentence(word_count: 8) }
    status { :pending }
    visitor { nil }

    trait :approved do
      status { :approved }
      approved_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
    end
  end
end
