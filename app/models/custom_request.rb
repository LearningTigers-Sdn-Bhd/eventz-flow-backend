class CustomRequest < ApplicationRecord
  belongs_to :exhibitor_kit

  enum status: { pending: 0, approved: 1, rejected: 2 }

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :resolved_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
