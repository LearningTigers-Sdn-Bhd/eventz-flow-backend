class CompleteEndedEventsJob < ApplicationJob
  queue_as :default

  def perform
    ended_events = Event.published.where(end_date: ...Time.current)
    count = ended_events.count

    if count.zero?
      Rails.logger.info "[CompleteEndedEventsJob] No events to complete"
      return
    end

    # Use update_all for better performance (single SQL query)
    # Note: This bypasses ActiveRecord callbacks (including webhook notifications)
    ended_events.update_all(status: :completed, updated_at: Time.current)

    # Alternative: Use find_each if need callbacks/webhooks to trigger
    # ended_events.find_each { |event| event.update!(status: :completed) }

    Rails.logger.info "[CompleteEndedEventsJob] Marked #{count} event(s) as completed"
  rescue StandardError => e
    Rails.logger.error "[CompleteEndedEventsJob] Failed: #{e.message}"
    raise # Re-raise to let Sidekiq handle retries
  end
end
