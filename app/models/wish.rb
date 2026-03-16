class Wish < ApplicationRecord
  belongs_to :event
  belongs_to :visitor, optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :guest_name, presence: true, length: { maximum: 100 }
  validates :message, presence: true, length: { maximum: 300 }

  scope :for_display, -> { approved.order(approved_at: :desc) }
end
