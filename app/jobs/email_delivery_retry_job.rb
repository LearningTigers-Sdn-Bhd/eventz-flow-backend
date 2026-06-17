class EmailDeliveryRetryJob < ApplicationJob
  queue_as :mailers

  def perform
    EmailDelivery.retryable
                 .where('next_retry_at <= ?', Time.current)
                 .find_each do |delivery|
      args = EmailDelivery::ArgsRebuilder.call(delivery)

      # Unsupported mailer/action for retry: stop re-picking it forever.
      unless args
        delivery.update!(failure_reason: 'unsupported_retry', next_retry_at: nil)
        next
      end

      delivery.increment!(:retry_count)
      EmailDeliveryJob.perform_later(delivery.id, delivery.mailer_name, delivery.mailer_action, args)
    end
  end
end
