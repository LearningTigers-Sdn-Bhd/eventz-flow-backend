FactoryBot.define do
  factory :exhibitor_package do
    event
    exhibitor_booth_price { association :exhibitor_booth_price, event: event }
    sequence(:name) { |n| "Package #{n} | Standard Booth" }
    inclusions { "6 Days / 5 Nights Twin-Sharing Accommodation\n3 Days Hosted Lunch & Dinner for 2 Delegates" }
    price { 7000.00 }
    quota { nil }
  end
end
