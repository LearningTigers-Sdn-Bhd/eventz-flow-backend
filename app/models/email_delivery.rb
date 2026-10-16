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
    skipped
  ].freeze

  PROBLEM_STATUSES = %w[failed bounced complained suppressed].freeze

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
  scope :for_search, lambda { |query|
    next all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    where(
      'recipient ILIKE :q OR subject ILIKE :q OR mailer_name ILIKE :q OR mailer_action ILIKE :q OR provider_message_id ILIKE :q',
      q: pattern
    )
  }
  scope :for_event, ->(event_id) { event_id.present? ? where(event_id: event_id) : all }
  MAX_RETRY_COUNT = 3

  # A row that was retried is superseded by its retry row, which carries the
  # real outcome.
  scope :not_retried, -> { where.not(id: EmailDelivery.where.not(resend_of_id: nil).select(:resend_of_id)) }

  # { ticket_id => problem status } for the tickets whose latest email did not
  # arrive, for flagging them in the attendee list in one query.
  def self.problem_status_by_ticket(ticket_ids)
    where(related_type: 'Ticket', related_id: ticket_ids, status: PROBLEM_STATUSES)
      .not_retried.order(:id).pluck(:related_id, :status).to_h
  end

  scope :retryable, -> { where(status: 'failed', failure_reason: TRANSIENT_FAILURE_REASONS).where('retry_count < ?', MAX_RETRY_COUNT) }

  def delivered_successfully?
    status == 'delivered'
  end

  def eligible_for_manual_resend?
    return true if status == 'failed'
    return true if status == 'sent' && sent_at.present? && sent_at <= 24.hours.ago

    false
  end

  # Organizers can also retry a bounced or suppressed address (after fixing
  # the email), which the admin Email Log deliberately does not offer.
  def eligible_for_organizer_resend?
    eligible_for_manual_resend? || %w[bounced suppressed].include?(status)
  end

  def transient_failure?
    status == 'failed' && TRANSIENT_FAILURE_REASONS.include?(failure_reason)
  end
end
