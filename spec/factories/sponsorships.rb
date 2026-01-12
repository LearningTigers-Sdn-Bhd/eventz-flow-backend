FactoryBot.define do
  factory :sponsor do
    association :group
    sequence(:name) { |n| "Sponsor #{n}" }
    website { "https://example.com" }
    industry { "Technology" }
    default_email { "sponsor@example.com" }
    default_contact_name { "John Doe" }
    is_active { true }
    association :created_by, factory: :user
  end

  factory :event_sponsorship_tier do
    association :group
    association :event
    sequence(:name) { |n| "Tier #{n}" }
    description { "A great sponsorship tier" }
    sponsorship_type_default { "monetary" }
    currency_default { "MYR" }
    suggested_value { 10000.00 }
  end

  factory :event_sponsorship do
    association :group
    association :event
    association :sponsor
    sequence(:title) { |n| "Sponsorship #{n}" }
    sponsorship_type { "monetary" }
    currency { "MYR" }
    total_sponsor_amount { 5000.00 }
    received_total { 0.00 }
    status { "pending" }
  end

  factory :event_sponsorship_payment do
    association :event_sponsorship
    amount { 1000.00 }
    currency { "MYR" }
    received_at { Time.current }
    add_attribute(:method) { "bank_transfer" }
  end

  factory :event_sponsorship_attachment do
    association :event_sponsorship
    media_type { "image" }
    attachment_type { "contract" }
    file_name { "contract.pdf" }
    association :uploaded_by, factory: :user
  end

  factory :event_sponsorship_item do
    association :event_sponsorship
    item_type { "in_kind" }
    title { "Hosting" }
    quantity { 1 }
    unit_value { 500.00 }
    total_value { 500.00 }
  end
end
