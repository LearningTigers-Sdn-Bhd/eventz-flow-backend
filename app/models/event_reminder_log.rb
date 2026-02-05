class EventReminderLog < ApplicationRecord
  belongs_to :event
  belongs_to :ticket

  validates :reminder_type, presence: true
  validates :reminder_type, inclusion: { in: %w[7_day 1_day] }
  validates :status, inclusion: { in: %w[sent failed] }
  validates :ticket_id, uniqueness: { scope: :reminder_type }

  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }
end
