class EmailDelivery::WebhookProcessor
  FINAL_STATUSES = %w[delivered bounced complained suppressed failed].freeze

  EVENT_STATUS_MAP = {
    'email.sent' => 'sent',
    'email.delivered' => 'delivered',
    'email.bounced' => 'bounced',
    'email.complained' => 'complained',
    'email.suppressed' => 'suppressed'
  }.freeze

  def self.call(event)
    new(event).call
  end

  def initialize(event)
    @event = event.with_indifferent_access
  end

  def call
    return log_account_alert if account_alert?

    delivery = EmailDelivery.find_by(provider_message_id: provider_message_id)
    return unless delivery

    status = EVENT_STATUS_MAP[@event[:type]]
    return unless status
    return if FINAL_STATUSES.include?(delivery.status) && delivery.status != status

    delivery.update!(attributes_for(status, delivery))
  end

  private

  # Account-level MillionSend events (reputation/quota). They carry no email
  # id, so they can't update a row; log loudly so a paused account is noticed.
  def account_alert?
    @event[:type].to_s.start_with?('deliverability.', 'quota.')
  end

  def log_account_alert
    level = @event[:type].end_with?('.warning') ? :warn : :error
    Rails.logger.public_send(level, "[EmailDelivery::WebhookProcessor] #{@event[:type]}: #{@event[:data].to_json}")
  end

  def provider_message_id
    @event.dig(:data, :email_id) || @event.dig(:data, :id)
  end

  def attributes_for(status, delivery)
    attrs = {
      status: status,
      metadata: merge_metadata(delivery)
    }

    timestamp_column = "#{status}_at"
    attrs[timestamp_column] = Time.current if EmailDelivery.column_names.include?(timestamp_column)
    attrs[:failure_reason] = status if %w[bounced complained suppressed].include?(status)
    attrs
  end

  def merge_metadata(delivery)
    current = delivery.metadata || {}
    events = Array(current['webhook_events'])
    current.merge('webhook_events' => events.push(@event.slice(:type, :data)))
  end
end
