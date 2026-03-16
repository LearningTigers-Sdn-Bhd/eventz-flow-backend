class CreditWallet < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  has_many :credit_transactions, dependent: :destroy

  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def deduct!(amount, description, metadata = {})
    raise "Insufficient credits" if balance < amount

    transaction do
      new_balance = balance - amount
      update!(balance: new_balance)
      credit_transactions.create!(
        transaction_type: :deduction,
        amount: -amount,
        balance_after: new_balance,
        description: description,
        metadata: metadata
      )
    end
  end

  def add_credits!(amount, transaction_type, description, metadata = {})
    transaction do
      new_balance = balance + amount
      update!(balance: new_balance)
      credit_transactions.create!(
        transaction_type: transaction_type,
        amount: amount,
        balance_after: new_balance,
        description: description,
        metadata: metadata
      )
    end
  end
end
