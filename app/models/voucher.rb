class Voucher < ApplicationRecord
  belongs_to :vendor
  belongs_to :event

  has_many :voucher_redemption_logs
  has_many :user_voucher_usages
end
