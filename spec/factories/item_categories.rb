FactoryBot.define do
  factory :item_category do
    sequence(:name) { |n| "Category #{n}" }
    active { true }
  end
end
