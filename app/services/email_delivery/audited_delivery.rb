class EmailDelivery::AuditedDelivery
  # Statuses that mean "this email is already in flight or done" — used by the
  # dedupe guard to avoid re-sending the same (related, action) email when a
  # caller fires more than once (double callbacks, webhook redelivery, etc).
  IN_FLIGHT_STATUSES = %w[queued sending sent delivered].freeze
  DEDUPE_WINDOW = 24.hours

  def self.deliver_now(mailer_name:, mailer_action:, args:, related: nil, metadata: {}, dedupe: false, event: nil)
    new(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe:, event:).deliver_now
  end

  def self.deliver_later(mailer_name:, mailer_action:, args:, related: nil, metadata: {}, dedupe: false, event: nil)
    instance = new(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe:, event:)
    existing = instance.duplicate_in_flight
    return existing if existing

    return instance.build_skipped_record if instance.disabled_by_event_settings?

    delivery = instance.build_record
    EmailDeliveryJob.perform_later(delivery.id, mailer_name, mailer_action, args)
    EmailDelivery::VoucherFollowUp.enqueue_after(mailer_name, mailer_action, args)
    delivery
  end

  # `event:` is an explicit override for when `related` can't reach its event
  # through an association (e.g. related is a User, or there's no related at
  # all) — pass it whenever the caller already has the event in scope rather
  # than relying on resolve_event's heuristics.
  def initialize(mailer_name:, mailer_action:, args:, related:, metadata:, dedupe: false, event: nil)
    @mailer_name = mailer_name
    @mailer_action = mailer_action
    @args = args
    @related = related
    @metadata = metadata || {}
    @dedupe = dedupe
    @event = event
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

  # True when the resolved event has this mailer/action's category disabled
  # (or has all emails disabled). Mailers we can't attribute to an event
  # (system mail like UserMailer, or a related record with no event path)
  # are never gated — fail-open rather than silently dropping mail we can't
  # confidently classify.
  def disabled_by_event_settings?
    event = resolve_event
    return false unless event

    setting = event.event_email_setting
    return false unless setting

    !setting.email_enabled?(@mailer_name, @mailer_action)
  rescue StandardError => e
    # This gate sits in front of every email the app sends — a bug here must
    # never become a reason mail silently stops going out. Log and send.
    Rails.logger.error("[EmailDelivery::AuditedDelivery] gating check failed for #{@mailer_name}##{@mailer_action}: #{e.message}")
    false
  end

  def build_skipped_record
    EmailDelivery.create!(
      provider: 'resend',
      mailer_name: @mailer_name,
      mailer_action: @mailer_action,
      status: 'skipped',
      related: @related,
      metadata: @metadata.merge(skipped_reason: 'event_email_setting_disabled')
    )
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
    return build_skipped_record if existing_delivery.nil? && disabled_by_event_settings?

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

  # Explicit `event:` wins. Otherwise covers every related type currently
  # passed to AuditedDelivery (Event itself, Ticket, TicketApplication,
  # ExhibitorKit, and anything else exposing #event). Widen this — or pass
  # `event:` explicitly at the call site — if a new related type needs gating.
  def resolve_event
    return @event if @event

    return @related if @related.is_a?(Event)
    return @args.find { |a| a.is_a?(Event) } if @args.any? { |a| a.is_a?(Event) }
    return @related.event if @related.respond_to?(:event)
    return @related.event_vendor.event if @related.respond_to?(:event_vendor)
    return @related.ticket.event if @related.respond_to?(:ticket)

    nil
  end
end
