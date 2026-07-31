require 'rails_helper'

RSpec.describe ExhibitorVoucher, type: :model do
  subject(:voucher) { build(:exhibitor_voucher) }

  it { should belong_to(:event) }
  it { should belong_to(:exhibitor_booth_price).optional }
  it { should belong_to(:exhibitor_package).optional }
  it { should belong_to(:redeemed_by_exhibitor_kit).optional }
  it { should validate_presence_of(:code) }
  it { should validate_uniqueness_of(:code) }
  it { should validate_numericality_of(:discount_value).is_greater_than(0) }

  describe 'event association' do
    it 'is available from the event' do
      voucher = create(:exhibitor_voucher)

      expect(voucher.event.exhibitor_vouchers).to contain_exactly(voucher)
    end
  end

  describe '.generate_code' do
    it 'returns an 8-character uppercase alphanumeric string' do
      expect(described_class.generate_code).to match(/\A[A-Z0-9]{8}\z/)
    end

    it 'does not collide with an existing code' do
      taken = create(:exhibitor_voucher)
      allow(SecureRandom).to receive(:alphanumeric).and_return(taken.code, 'FRESH123')

      expect(described_class.generate_code).to eq('FRESH123')
    end
  end

  describe 'percentage_off capped at 100' do
    it 'rejects a percentage_off voucher over 100' do
      voucher = build(:exhibitor_voucher, discount_type: :percentage_off, discount_value: 150)

      expect(voucher).not_to be_valid
      expect(voucher.errors[:discount_value]).to be_present
    end

    it 'allows a fixed_amount_off voucher over 100' do
      voucher = build(:exhibitor_voucher, :fixed_amount, discount_value: 5000)

      expect(voucher).to be_valid
    end
  end

  describe 'scope consistency' do
    let(:event) { create(:event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event) }
    let(:other_event_booth_price) { create(:exhibitor_booth_price, exhibitor_zone: nil) }
    let(:package) { create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price) }

    it 'rejects a booth price from a different event' do
      voucher = build(:exhibitor_voucher, event: event, exhibitor_booth_price: other_event_booth_price)

      expect(voucher).not_to be_valid
    end

    it 'rejects a package that does not belong to the scoped booth price' do
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil)
      mismatched_package = create(:exhibitor_package, event: event, exhibitor_booth_price: other_price)
      voucher = build(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: mismatched_package)

      expect(voucher).not_to be_valid
    end

    it 'accepts a matching booth price and package pair' do
      voucher = build(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: package)

      expect(voucher).to be_valid
    end
  end

  describe '#matches_selection?' do
    let(:event) { create(:event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event) }
    let(:other_booth_price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: nil) }
    let(:package) { create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price) }

    it 'matches any selection when unscoped' do
      voucher = build(:exhibitor_voucher, event: event)

      expect(voucher.matches_selection?(booth_price: booth_price, package: nil)).to be(true)
      expect(voucher.matches_selection?(booth_price: other_booth_price, package: nil)).to be(true)
    end

    it 'matches only the scoped booth price' do
      voucher = build(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price)

      expect(voucher.matches_selection?(booth_price: booth_price, package: nil)).to be(true)
      expect(voucher.matches_selection?(booth_price: other_booth_price, package: nil)).to be(false)
    end

    it 'matches only the scoped package' do
      voucher = build(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: package)

      expect(voucher.matches_selection?(booth_price: booth_price, package: package)).to be(true)
      expect(voucher.matches_selection?(booth_price: booth_price, package: nil)).to be(false)
    end
  end
end
