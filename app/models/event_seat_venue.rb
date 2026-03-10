class EventSeatVenue < ApplicationRecord
  belongs_to :event_seat_session
  delegate :event, to: :event_seat_session, allow_nil: true

  has_many :event_seat_sections, dependent: :destroy
  accepts_nested_attributes_for :event_seat_sections, allow_destroy: true
  has_one_attached :image

  validates :name, presence: true

  after_commit :sync_session_location, on: :update

  private

  def sync_session_location
    return unless saved_change_to_name?

    session = event_seat_session
    return if session.nil?

    primary_venue = session.event_seat_venues.order(:id).first
    return unless primary_venue&.id == id
    return if session.location == name

    session.update_columns(location: name, updated_at: Time.current)
  end
end
