class VoucherRedemptionLog < ApplicationRecord
  belongs_to :voucher
  belongs_to :user
  # belongs_to :redeemer_staff
  # belongs_to :redemption_location
end
