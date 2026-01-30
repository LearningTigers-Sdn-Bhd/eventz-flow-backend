class EventSeatSection < ApplicationRecord
  belongs_to :event_seat_venue
  has_many :event_ticket_seats, dependent: :destroy

  validates :name, presence: true
end
