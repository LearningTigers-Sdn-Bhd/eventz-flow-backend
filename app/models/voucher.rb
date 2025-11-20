class Voucher < ApplicationRecord
  belongs_to :vendor, class_name: "User", foreign_key: "vendor_id"
  belongs_to :event

  has_many :voucher_redemption_logs
  has_many :voucher_usages

  enum :voucher_type, { 
    fixed_amount: 'FIXED_AMOUNT', 
    percentage: 'PERCENTAGE', 
    free_item: 'FREE_ITEM' 
  }
end
