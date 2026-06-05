class EmailDelivery::AuditedDelivery
  def self.deliver_now(mailer_name:, mailer_action:, args:, related: nil, metadata: {})
    new(mailer_name:, mailer_action:, args:, related:, metadata:).deliver_now
  end

  def self.deliver_later(mailer_name:, mailer_action:, args:, related: nil, metadata: {})
    delivery = new(mailer_name:, mailer_action:, args:, related:, metadata:).build_record
    EmailDeliveryJob.perform_later(delivery.id, mailer_name, mailer_action, args)
    delivery
  end

  def initialize(mailer_name:, mailer_action:, args:, related:, metadata:)
    @mailer_name = mailer_name
    @mailer_action = mailer_action
    @args = args
    @related = related
    @metadata = metadata || {}
  end

  def build_record
    message_delivery = build_message_delivery
    message = message_delivery.respond_to?(:message) ? message_delivery.message : nil

    EmailDelivery.create!(
      provider: 'resend',
      mailer_name: @mailer_name,
      mailer_action: @mailer_action,
      recipient: Array(message&.to).first,
      recipients: {
        to: Array(message&.to),
        cc: Array(message&.cc),
        bcc: Array(message&.bcc)
      },
      subject: message&.subject,
      status: 'queued',
      related: @related,
      metadata: @metadata
    )
  end

  def deliver_now(existing_delivery = nil)
    delivery = existing_delivery || build_record
    message_delivery = build_message_delivery
    message = message_delivery.respond_to?(:message) ? message_delivery.message : nil

    delivery.update!(status: 'sending')
    message_delivery.deliver_now

    delivery.update!(
      status: 'sent',
      provider_message_id: message&.message_id.presence,
      sent_at: Time.current,
      last_error: nil,
      failure_reason: nil
    )
    delivery
  rescue StandardError => e
    attrs = EmailDelivery::FailureClassifier.call(e)
    delivery.update!(
      status: 'failed',
      failed_at: Time.current,
      last_error: attrs[:last_error],
      failure_reason: attrs[:failure_reason],
      next_retry_at: attrs[:next_retry_at]
    )
    delivery
  end

  private

  def build_message_delivery
    @mailer_name.constantize.public_send(@mailer_action, *@args)
  end
end
