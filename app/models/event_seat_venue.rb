class EventSeatVenue < ApplicationRecord
  belongs_to :event_seat_session
  has_many :event_seat_sections, dependent: :destroy
  has_one_attached :image

  validates :name, presence: true
end
