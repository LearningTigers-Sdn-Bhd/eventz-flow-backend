# Tracks the redemption count of a specific voucher by a specific user.
class UserVoucherUsage < ApplicationRecord
  # --- Associations ---
  belongs_to :user
  belongs_to :voucher

  # --- Validations ---
  validates :user, presence: true
  validates :voucher, presence: true
  
  # Ensures a user cannot have multiple usage records for the same voucher
  validates :user_id, uniqueness: { scope: :voucher_id, message: "Usage record already exists for this voucher and user." }

  # FIX: Removed presence validation on redemption_count. 
  # Since the column is nullable in the schema and has a default (0) in the model, 
  # the numericality check is sufficient, and increment! handles NULL gracefully.
  validates :redemption_count, numericality: { greater_than_or_equal_to: 0 }
  
  # --- Defaults ---
  attribute :redemption_count, :integer, default: 0
end