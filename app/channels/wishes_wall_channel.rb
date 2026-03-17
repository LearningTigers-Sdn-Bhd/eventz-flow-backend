class WishesWallChannel < ApplicationCable::Channel
  def subscribed
    stream_from "wishes_wall_event_#{params[:event_id]}"
    transmit(type: 'state', wishes: current_wishes)
  end

  def unsubscribed
    stop_all_streams
  end

  def request_state
    transmit(type: 'state', wishes: current_wishes)
  end

  private

  def current_wishes
    Event.find(params[:event_id]).wishes.for_display.map do |wish|
      {
        id: wish.id,
        guest_name: wish.guest_name,
        message: wish.message,
        approved_at: wish.approved_at&.iso8601
      }
    end
  end
end
