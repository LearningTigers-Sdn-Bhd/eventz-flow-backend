class WelcomeScreenBroadcastJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    WelcomeScreenQueueService.process_next(event_id)
  end
end
