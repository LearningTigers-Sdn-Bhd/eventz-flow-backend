class CreditDeduction < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  belongs_to :event, optional: true

  enum :status, { pending: 0, sent: 1, failed: 2 }
  # Channel can be anything like 'whatsapp', 'tts', 'sms'

  validates :channel, presence: true
  validates :credits, presence: true, numericality: { greater_than: 0 }
end
