class BusinessMatchingChannel < ApplicationCable::Channel
  def subscribed
    # streams for a specific event's business matching updates
    stream_from "business_matching_event_#{params[:event_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end
end
