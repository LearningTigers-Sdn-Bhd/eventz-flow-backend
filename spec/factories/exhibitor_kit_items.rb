FactoryBot.define do
  factory :exhibitor_kit_item do
    association :exhibitor_kit
    association :rentable_item, factory: :rentable_item # Ensure rentable_item is active by default factory setting

    quantity { Faker::Number.between(from: 1, to: 10) }
    agreed_price { Faker::Commerce.price(range: 10.0..1000.0) }
    notes { Faker::Lorem.sentence }

    # After creating the exhibitor_kit_item, ensure the rentable_item is linked to the kit's event
    after(:create) do |exhibitor_kit_item|
      event = exhibitor_kit_item.exhibitor_kit.event
      rentable_item = exhibitor_kit_item.rentable_item

      # Ensure an EventRentableItem exists linking the rentable_item to the event
      # Use find_or_create_by to avoid creating duplicates if already exists
      EventRentableItem.find_or_create_by!(event: event, rentable_item: rentable_item)
    end
  end
end