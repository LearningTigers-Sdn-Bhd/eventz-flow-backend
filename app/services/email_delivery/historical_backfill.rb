class EmailDelivery::HistoricalBackfill
  STATUS_MAP = {
    'sent' => 'sent',
    'delivered' => 'delivered',
    'bounced' => 'bounced',
    'complained' => 'complained',
    'failed' => 'failed'
  }.freeze

  def self.call(rows)
    new(rows).call
  end

  def initialize(rows)
    @rows = rows
  end

  def call
    @rows.each { |row| import_row(row.with_indifferent_access) }
  end

  private

  def import_row(row)
    provider_message_id = row[:id]
    return if provider_message_id.blank?
    return if EmailDelivery.exists?(provider_message_id: provider_message_id)

    created_at = Time.zone.parse(row[:created_at].to_s) rescue Time.current
    status = STATUS_MAP[row[:last_event].to_s] || 'sent'

    EmailDelivery.create!(
      provider: 'resend',
      provider_message_id: provider_message_id,
      mailer_name: 'ProviderBackfill',
      mailer_action: 'unknown',
      recipient: Array(row[:to]).first,
      recipients: { to: Array(row[:to]), cc: [], bcc: [] },
      subject: row[:subject],
      status: status,
      sent_at: created_at,
      delivered_at: status == 'delivered' ? created_at : nil,
      metadata: row.to_h.merge(historical_backfill: true)
    )
  end
end
