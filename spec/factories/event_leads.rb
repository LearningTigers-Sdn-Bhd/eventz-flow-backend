# spec/factories/event_leads.rb

FactoryBot.define do
  factory :event_lead do
    association :event_vendor

    # Default to Visitor as leadable
    association :leadable, factory: :visitor

    notes { nil }
    scanned_by { nil }

    trait :with_notes do
      notes { 'Interested in corporate partnership' }
    end

    trait :from_ticket do
      association :leadable, factory: :ticket
    end

    trait :with_scanner do
      association :scanned_by, factory: :user
    end
  end
end
