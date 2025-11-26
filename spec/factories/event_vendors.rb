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
    end

    trait :merchant do
      type { 'Merchant' }
    end

    factory :exhibitor, class: 'Exhibitor', traits: [:exhibitor] do
      # The presence of exhibitor_kit is validated in Exhibitor model,
      # so ensure a kit is built when creating an exhibitor in tests.
      after(:create) do |exhibitor|
        exhibitor.exhibitor_kit ||= build(:exhibitor_kit, event_vendor: exhibitor)
      end
    end

    factory :merchant, class: 'Merchant', traits: [:merchant]
  end
end