# spec/factories/event_vendors.rb

FactoryBot.define do
  factory :event_vendor do
    association :event
    association :vendor, factory: :vendor_user
    redirect_url { 'https://example.com/vendor' }
    poster_url { nil }
    type { 'Merchant' } # Default type

    trait :exhibitor do
      type { 'Exhibitor' }
      association :exhibitor_owner
    end

    trait :merchant do
      type { 'Merchant' }
    end

    factory :exhibitor, class: 'Exhibitor', traits: [:exhibitor] do
      association :exhibitor_owner

      trait :independent do
        exhibitor_owner { nil }
      end
    end

    factory :merchant, class: 'Merchant', traits: [:merchant]
  end
end
