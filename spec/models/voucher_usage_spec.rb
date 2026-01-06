require 'rails_helper'

RSpec.describe VoucherUsage, type: :model do
  describe 'associations' do
    it { should belong_to(:voucher) }
    it { should belong_to(:redeemer) }
  end

  describe 'validations' do
    it { should validate_presence_of(:voucher) }
    it { should validate_presence_of(:redeemer) }
    it { should validate_presence_of(:redemption_count) }
    it { should validate_numericality_of(:redemption_count).is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it { should define_enum_for(:redeemer_type).with_values(User: 0, Visitor: 1) }
  end

  describe 'callbacks' do
    describe '#set_default_redemption_count' do
      let(:voucher) { create(:voucher) }
      let(:visitor) { create(:visitor) }

      it 'sets redemption_count to 0 for new records' do
        voucher_usage = VoucherUsage.new(voucher: voucher, redeemer: visitor)
        expect(voucher_usage.redemption_count).to eq(0)
      end

      it 'does not override redemption_count if already set' do
        voucher_usage = VoucherUsage.new(voucher: voucher, redeemer: visitor, redemption_count: 5)
        expect(voucher_usage.redemption_count).to eq(5)
      end
    end
  end
end
