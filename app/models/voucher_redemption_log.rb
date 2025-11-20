# Audits every successful voucher redemption transaction.
class VoucherRedemptionLog < ApplicationRecord
  # --- Enums ---
  enum :redeemer_type, { User: 0, Visitor: 1 }

  # --- Associations ---
  belongs_to :voucher
  belongs_to :redeemer, polymorphic: true # The user or visitor who used the voucher
  
  # The staff member who processed the redemption, if applicable (staff_id is passed to the service)
  # NOTE: Assuming 'redeemer_staff_id' is a column storing a User ID.
  # If you have a separate Staff model, this class_name needs adjustment.
  belongs_to :redeemer_staff, class_name: 'User', foreign_key: 'redeemer_staff_id', optional: true

  # --- Validations (Inferred from service data) ---
  validates :voucher, presence: true
  validates :redeemer, presence: true
  validates :redemption_timestamp, presence: true
  validates :redemption_status, presence: true
  
  # Monetary fields used in the log
  validates :transaction_gross_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_applied_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :transaction_net_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Assuming this status is used
  enum :redemption_status, { completed: 'Completed', cancelled: 'Cancelled' }
end