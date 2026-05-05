class TicketScanLog < ApplicationRecord
  belongs_to :ticket
  belongs_to :event
  belongs_to :scanned_by, class_name: 'User'

  validates :day_index, numericality: { only_integer: true, greater_than: 0 }
  validates :scanned_at, presence: true
  validates :ticket_id, uniqueness: { scope: :day_index }
end
