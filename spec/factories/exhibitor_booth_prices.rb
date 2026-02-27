FactoryBot.define do
  factory :exhibitor_booth_price do
    event
    exhibitor_zone { association :exhibitor_zone, event: event }
    booth_type { 'shell_scheme' }
    sequence(:label) { |n| "Tier #{n}" }
    price { 1500.00 }
  end
end
