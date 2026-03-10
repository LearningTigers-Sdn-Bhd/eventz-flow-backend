class WelcomeScreenChannel < ApplicationCable::Channel
  def subscribed
    stream_from "welcome_screen_event_#{params[:event_id]}"
    transmit(current_state)
  end

  def unsubscribed
    stop_all_streams
  end

  def request_state
    transmit(current_state)
  end

  private

  def current_state
    WelcomeScreenQueueService.current_state(params[:event_id])
  end
end
