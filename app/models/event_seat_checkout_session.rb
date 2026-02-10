class EventSeatCheckoutSession < ApplicationRecord
  belongs_to :event_seat_session

  LOCK_DURATION = 10.minutes

  def expired?
    updated_at < LOCK_DURATION.ago
  end
end
