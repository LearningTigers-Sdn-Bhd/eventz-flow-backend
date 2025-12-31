class PaymentDetail < ApplicationRecord
  belongs_to :user

  validates :bank_name, presence: true
  validates :account_number, presence: true
  validates :account_name, presence: true
  validates :user_id, uniqueness: true
end
