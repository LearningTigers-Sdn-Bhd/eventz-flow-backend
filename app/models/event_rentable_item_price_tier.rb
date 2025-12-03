class EventRentableItemPriceTier < ApplicationRecord
  belongs_to :event_rentable_item

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validates :label, presence: true
end
