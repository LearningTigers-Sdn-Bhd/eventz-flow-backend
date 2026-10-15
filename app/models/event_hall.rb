# A counted area of an event (e.g. "Hall A" on "Level 1"). Independent of
# EventLocation, which is for ticket scanning. counter_venue_id points at the
# matching venue on the people-counter service.
class EventHall < ApplicationRecord
  belongs_to :event, inverse_of: :event_halls

  validates :name, presence: true, uniqueness: { scope: :event_id, message: "already exists for this event" }

  scope :ordered, -> { order(:floor, :position, :name) }
end
