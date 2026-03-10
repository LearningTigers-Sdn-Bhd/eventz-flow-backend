class EventSeatSessionChannel < ApplicationCable::Channel
  def subscribed
    session = EventSeatSession.find_by(public_id: params[:session_id])
    if session&.published?
      stream_from "event_seat_session_#{session.public_id}"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when cable is unsubscribed
  end
end
