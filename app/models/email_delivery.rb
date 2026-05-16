class EmailDelivery < ApplicationRecord
  STATUSES = %w[
    queued
    sending
    sent
    delivered
    failed
    bounced
    complained
    suppressed
  ].freeze

  TRANSIENT_FAILURE_REASONS = %w[
    provider_daily_limit
    rate_limit
    provider_error
    network_timeout
  ].freeze

  belongs_to :related, polymorphic: true, optional: true
  belongs_to :resend_of, class_name: 'EmailDelivery', optional: true
  has_many :resends, class_name: 'EmailDelivery', foreign_key: :resend_of_id, inverse_of: :resend_of, dependent: :nullify

  validates :provider, presence: true
  validates :mailer_name, presence: true
  validates :mailer_action, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :provider_message_id, uniqueness: true, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_status, ->(status) { status.present? ? where(status: status) : all }
  scope :for_recipient, lambda { |recipient|
    recipient.present? ? where('recipient ILIKE ?', "%#{sanitize_sql_like(recipient)}%") : all
  }
  scope :retryable, -> { where(status: 'failed', failure_reason: TRANSIENT_FAILURE_REASONS) }

  def delivered_successfully?
    status == 'delivered'
  end

  def eligible_for_manual_resend?
    return true if status == 'failed'
    return true if status == 'sent' && sent_at.present? && sent_at <= 24.hours.ago

    false
  end

  def transient_failure?
    status == 'failed' && TRANSIENT_FAILURE_REASONS.include?(failure_reason)
  end
end
