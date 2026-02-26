FactoryBot.define do
  factory :exhibitor_booth_price do
    event
    exhibitor_zone_quota { association :exhibitor_zone_quota, event: event }
    booth_type { "shell_scheme" }
    sequence(:label) { |n| "Tier #{n}" }
    price { 1500.00 }
  end
end
