class Voucher < ApplicationRecord
  belongs_to :vendor, class_name: "User", foreign_key: "vendor_id"
  belongs_to :event

  has_many :voucher_redemption_logs
  has_many :voucher_usages

  enum :status, { active: 0, inactive: 1 }

  enum :voucher_type, { 
    fixed_amount: 0, 
    percentage: 1, 
    free_item: 2 
  }

  scope :for_event, ->(event) { where(event: event) }

  # Check if voucher has remaining quota for redemption
  # Returns true if unlimited, or if redeemed count is less than total available
  def has_quota_remaining?
    return true if is_unlimited
    return true if total_redemption_available.to_i.zero?

    redeemed_count.to_i < total_redemption_available.to_i
  end
end
