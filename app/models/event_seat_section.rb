class EventSeatSection < ApplicationRecord
  belongs_to :event_seat_venue
  has_many :event_ticket_seats, dependent: :destroy
  accepts_nested_attributes_for :event_ticket_seats, allow_destroy: true

  validates :name, presence: true
end
