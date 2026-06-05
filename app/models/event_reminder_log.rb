class EventReminderLog < ApplicationRecord
  REMINDER_TYPES = %w[7_day 1_day payment_pending_weekly].freeze

  before_validation :normalize_reminder_period_key

  belongs_to :event
  belongs_to :ticket

  validates :reminder_type, presence: true
  validates :reminder_type, inclusion: { in: REMINDER_TYPES }
  validates :status, inclusion: { in: %w[sent failed] }
  validates :reminder_period_key, presence: true, if: :payment_pending_weekly?
  validates :reminder_period_key, absence: true, unless: :payment_pending_weekly?
  validates :ticket_id, uniqueness: { scope: %i[reminder_type reminder_period_key] }

  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }

  def payment_pending_weekly?
    reminder_type == 'payment_pending_weekly'
  end

  private

  def normalize_reminder_period_key
    self.reminder_period_key = reminder_period_key&.strip.presence
  end
end
