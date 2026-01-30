class EventTicketSeat < ApplicationRecord
  belongs_to :event_seat_section
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true

  validates :name, presence: true
end
