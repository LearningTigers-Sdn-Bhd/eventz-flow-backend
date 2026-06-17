class EmailDelivery::AuditedDelivery
  # Statuses that mean "this email is already in flight or done" — used by the
  # dedupe guard to avoid re-sending the same (related, action) email when a
  # caller fires more than once (double callbacks, webhook redelivery, etc).
  IN_FLIGHT_STATUSES = %w[queued sending sent delivered].freeze
  DEDUPE_WINDOW = 24.hours

  def self.deliver_now(mailer_name:, mailer_action:, args:, related: nil, metadata: {}, dedupe: false)
    new(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe:).deliver_now
  end

  def self.deliver_later(mailer_name:, mailer_action:, args:, related: nil, metadata: {}, dedupe: false)
    instance = new(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe:)
    existing = instance.duplicate_in_flight
    return existing if existing

    delivery = instance.build_record
    EmailDeliveryJob.perform_later(delivery.id, mailer_name, mailer_action, args)
    delivery
  end

  def initialize(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe: false)
    @mailer_name = mailer_name
    @mailer_action = mailer_action
    @args = args
    @related = related
    @metadata = metadata || {}
    @dedupe = dedupe
  end

  # Returns an existing in-flight/sent delivery for the same (related, mailer,
  # action) within the dedupe window, or nil. Only active when dedupe: true and
  # a related record is present (we can't safely dedupe without an anchor).
  def duplicate_in_flight
    return nil unless @dedupe && @related

    EmailDelivery
      .where(related: @related, mailer_name: @mailer_name, mailer_action: @mailer_action)
      .where(status: IN_FLIGHT_STATUSES)
      .where('created_at >= ?', DEDUPE_WINDOW.ago)
      .order(created_at: :desc)
      .first
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
      failure_reason: nil,
      next_retry_at: nil
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
