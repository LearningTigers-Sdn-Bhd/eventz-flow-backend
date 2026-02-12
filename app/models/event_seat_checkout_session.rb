class EventSeatCheckoutSession < ApplicationRecord
  belongs_to :event_seat_session

  LOCK_DURATION = 15.minutes

  def expired?
    created_at < LOCK_DURATION.ago
  end
end
