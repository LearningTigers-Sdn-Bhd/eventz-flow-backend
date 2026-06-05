class EmailDeliveryRetryJob < ApplicationJob
  queue_as :mailers

  def perform
    EmailDelivery.retryable
                 .where('next_retry_at <= ?', Time.current)
                 .find_each do |delivery|
      delivery.increment!(:retry_count)
      EmailDelivery::Resender.call(delivery)
    end
  end
end
