class EventRentableItem < ApplicationRecord
  belongs_to :event
  belongs_to :rentable_item
  has_many :event_rentable_item_price_tiers, dependent: :destroy
end