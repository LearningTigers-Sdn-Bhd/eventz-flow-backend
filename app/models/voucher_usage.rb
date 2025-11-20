# Tracks voucher usage per redeemer (User or Visitor)
class VoucherUsage < ApplicationRecord
  # --- Callbacks ---
  after_initialize :set_default_redemption_count, if: :new_record?

  # --- Enums ---
  enum :redeemer_type, { User: 0, Visitor: 1 }

  # --- Associations ---
  belongs_to :voucher
  belongs_to :redeemer, polymorphic: true

  # --- Validations ---
  validates :voucher, presence: true
  validates :redeemer, presence: true
  validates :redemption_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  private

  def set_default_redemption_count
    self.redemption_count ||= 0
  end
end
