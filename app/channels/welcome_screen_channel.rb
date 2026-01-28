class WelcomeScreenChannel < ApplicationCable::Channel
  def subscribed
    stream_from "welcome_screen_event_#{params[:event_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
