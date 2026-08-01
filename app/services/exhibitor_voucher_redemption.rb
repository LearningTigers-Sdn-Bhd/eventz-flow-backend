class ExhibitorVoucherRedemption
  class InvalidVoucher < StandardError; end
  class VoucherMismatch < StandardError; end

  INVALID_MESSAGE = 'Voucher code is invalid or already used'.freeze
  MISMATCH_MESSAGE = 'Voucher does not apply to the selected booth price or package'.freeze

  def self.preview(event:, code:, booth_price:, package:, base_price:)
    return { price: base_price, voucher: nil } if code.blank?

    voucher = event.exhibitor_vouchers.active.find_by(code: code)
    raise InvalidVoucher, INVALID_MESSAGE if voucher.nil?
    unless voucher.matches_selection?(booth_price: booth_price, package: package)
      raise VoucherMismatch, MISMATCH_MESSAGE
    end

    { price: adjusted_price(voucher, base_price), voucher: voucher }
  end

  def self.redeem!(voucher:, exhibitor_kit:)
    voucher.with_lock do
      raise InvalidVoucher, INVALID_MESSAGE unless voucher.active?

      voucher.update!(
        status: :redeemed,
        redeemed_by_exhibitor_kit: exhibitor_kit,
        redeemed_at: Time.current
      )
    end
  rescue ActiveRecord::RecordNotFound
    raise InvalidVoucher, INVALID_MESSAGE
  end

  def self.adjusted_price(voucher, base_price)
    case voucher.discount_type
    when 'percentage_off'
      (base_price * (1 - voucher.discount_value / 100.0)).round(2)
    when 'fixed_amount_off'
      [base_price - voucher.discount_value, 0].max
    when 'flat_price'
      voucher.discount_value
    end
  end
  private_class_method :adjusted_price
end
