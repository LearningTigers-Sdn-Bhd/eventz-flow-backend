require 'rails_helper'

RSpec.describe ExhibitorVoucherRedemption do
  let(:event) { create(:event) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }
  let(:other_booth_price) do
    create(:exhibitor_booth_price, event: event, exhibitor_zone: nil, price: 2000)
  end
  let(:package) do
    create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: 1500)
  end

  describe '.preview' do
    it 'returns the base price unchanged when code is blank' do
      result = described_class.preview(event: event, code: nil, booth_price: booth_price,
        package: nil, base_price: 1000)

      expect(result).to eq(price: 1000, voucher: nil)
    end

    it 'applies a percentage_off voucher' do
      voucher = create(:exhibitor_voucher, event: event, discount_type: :percentage_off,
        discount_value: 20)

      result = described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
        package: nil, base_price: 1000)

      expect(result).to eq(price: 800.0, voucher: voucher)
    end

    it 'applies a fixed_amount_off voucher, floored at zero' do
      voucher = create(:exhibitor_voucher, :fixed_amount, event: event, discount_value: 1500)

      result = described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
        package: nil, base_price: 1000)

      expect(result[:price]).to eq(0)
    end

    it 'applies a flat_price voucher, ignoring base price' do
      voucher = create(:exhibitor_voucher, :flat_price, event: event, discount_value: 3000)

      result = described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
        package: nil, base_price: 999)

      expect(result[:price]).to eq(3000)
    end

    it 'raises InvalidVoucher for an unknown code' do
      expect do
        described_class.preview(event: event, code: 'NOPE1234', booth_price: booth_price,
          package: nil, base_price: 1000)
      end.to raise_error(described_class::InvalidVoucher)
    end

    it 'raises InvalidVoucher for an already-redeemed code' do
      voucher = create(:exhibitor_voucher, :redeemed, event: event)

      expect do
        described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
          package: nil, base_price: 1000)
      end.to raise_error(described_class::InvalidVoucher)
    end

    it 'raises InvalidVoucher for a code belonging to another event' do
      voucher = create(:exhibitor_voucher)

      expect do
        described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
          package: nil, base_price: 1000)
      end.to raise_error(described_class::InvalidVoucher)
    end

    it 'raises VoucherMismatch when scoped to a different booth price' do
      voucher = create(:exhibitor_voucher, event: event,
        exhibitor_booth_price: other_booth_price)

      expect do
        described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
          package: nil, base_price: 1000)
      end.to raise_error(described_class::VoucherMismatch)
    end

    it 'raises VoucherMismatch when scoped to a package the selection did not choose' do
      voucher = create(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: package)

      expect do
        described_class.preview(event: event, code: voucher.code, booth_price: booth_price,
          package: nil, base_price: 1000)
      end.to raise_error(described_class::VoucherMismatch)
    end
  end

  describe '.redeem!' do
    it 'marks the voucher redeemed and links the kit' do
      voucher = create(:exhibitor_voucher, event: event)
      kit = create(:exhibitor_kit)

      described_class.redeem!(voucher: voucher, exhibitor_kit: kit)

      expect(voucher.reload).to have_attributes(
        status: 'redeemed',
        redeemed_by_exhibitor_kit_id: kit.id
      )
      expect(voucher.redeemed_at).to be_present
    end

    it 'rejects a second redemption from a stale active instance' do
      voucher = create(:exhibitor_voucher, event: event)
      stale_voucher = described_class.preview(
        event: event,
        code: voucher.code,
        booth_price: booth_price,
        package: nil,
        base_price: 1000
      )[:voucher]
      first_kit = create(:exhibitor_kit)
      second_kit = create(:exhibitor_kit)
      voucher.update!(
        status: :redeemed,
        redeemed_by_exhibitor_kit: first_kit,
        redeemed_at: Time.current
      )

      expect do
        described_class.redeem!(voucher: stale_voucher, exhibitor_kit: second_kit)
      end.to raise_error(described_class::InvalidVoucher, 'Voucher code is invalid or already used')
      expect(voucher.reload.redeemed_by_exhibitor_kit).to eq(first_kit)
    end

    it 'normalizes a deletion race to InvalidVoucher' do
      voucher = create(:exhibitor_voucher, event: event)
      stale_voucher = described_class.preview(
        event: event,
        code: voucher.code,
        booth_price: booth_price,
        package: nil,
        base_price: 1000
      )[:voucher]
      voucher.destroy!

      expect do
        described_class.redeem!(
          voucher: stale_voucher,
          exhibitor_kit: create(:exhibitor_kit)
        )
      end.to raise_error(described_class::InvalidVoucher, 'Voucher code is invalid or already used')
    end
  end
end
