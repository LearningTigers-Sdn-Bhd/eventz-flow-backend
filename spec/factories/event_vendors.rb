# spec/factories/event_vendors.rb

FactoryBot.define do
  factory :event_vendor do
    association :event
    association :vendor, factory: [:user, :vendor]
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
      trait :with_exhibitor_kit do
        after(:create) { |exhibitor| create(:exhibitor_kit, event_vendor: exhibitor) }
      end

      trait :with_multiple_exhibitor_kits do
        after(:create) do |exhibitor|
          create_list(:exhibitor_kit, 2, event_vendor: exhibitor)
        end
      end
    end

    factory :merchant, class: 'Merchant', traits: [:merchant]
  end
end
