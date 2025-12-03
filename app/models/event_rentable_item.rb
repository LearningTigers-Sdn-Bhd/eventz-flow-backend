class EventRentableItem < ApplicationRecord
  belongs_to :event
  belongs_to :rentable_item
end