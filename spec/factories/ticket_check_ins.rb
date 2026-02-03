FactoryBot.define do
  factory :ticket_check_in do
    ticket
    check_in_at { Time.current }
    scanned_by { nil }

    trait :with_scanner do
      association :scanned_by, factory: :user
    end
  end
end
