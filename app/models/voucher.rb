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
end
