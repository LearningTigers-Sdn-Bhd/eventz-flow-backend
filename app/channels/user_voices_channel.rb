class UserVoicesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user_voices_#{params[:user_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
