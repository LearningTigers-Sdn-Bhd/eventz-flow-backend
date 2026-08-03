class EmailDeliveryJob < ApplicationJob
  queue_as :mailers
  self.log_arguments = false

  def perform(delivery_id, mailer_name, mailer_action, args)
    delivery = EmailDelivery.find(delivery_id)
    EmailDelivery::AuditedDelivery.new(
      mailer_name: mailer_name,
      mailer_action: mailer_action,
      args: args,
      related: delivery.related,
      metadata: delivery.metadata
    ).deliver_now(delivery)
  end
end
