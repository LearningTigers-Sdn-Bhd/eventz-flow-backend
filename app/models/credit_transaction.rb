class CreditTransaction < ApplicationRecord
  belongs_to :credit_wallet

  enum :transaction_type, { purchase: 0, refund: 1, bonus: 2, deduction: 3 }

  validates :transaction_type, presence: true
  validates :amount, presence: true
  validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
