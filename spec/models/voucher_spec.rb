require 'rails_helper'

RSpec.describe Voucher, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:vendor).class_name('User') }
    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:voucher_redemption_logs) }
    it { is_expected.to have_many(:voucher_usages) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, inactive: 1) }
    it { is_expected.to define_enum_for(:voucher_type).with_values(fixed_amount: 0, percentage: 1, free_item: 2) }
  end

  describe '#has_quota_remaining?' do
    let(:voucher) { build(:voucher) }

    context 'when voucher is unlimited' do
      let(:voucher) { build(:voucher, :unlimited) }

      it 'returns true regardless of redeemed count' do
        voucher.redeemed_count = 1000
        expect(voucher.has_quota_remaining?).to be true
      end

      it 'returns true even with total_redemption_available set' do
        voucher.total_redemption_available = 10
        voucher.redeemed_count = 100
        expect(voucher.has_quota_remaining?).to be true
      end
    end

    context 'when voucher is limited (is_unlimited: false)' do
      context 'with total_redemption_available = 0 (legacy unlimited)' do
        let(:voucher) { build(:voucher, is_unlimited: false, total_redemption_available: 0, redeemed_count: 100) }

        it 'returns true (legacy unlimited behavior)' do
          expect(voucher.has_quota_remaining?).to be true
        end
      end

      context 'with total_redemption_available = nil (legacy unlimited)' do
        let(:voucher) { build(:voucher, is_unlimited: false, total_redemption_available: nil, redeemed_count: 100) }

        it 'returns true (legacy unlimited behavior)' do
          expect(voucher.has_quota_remaining?).to be true
        end
      end

      context 'with quota remaining' do
        let(:voucher) { build(:voucher, is_unlimited: false, total_redemption_available: 100, redeemed_count: 50) }

        it 'returns true' do
          expect(voucher.has_quota_remaining?).to be true
        end
      end

      context 'with quota exhausted' do
        let(:voucher) { build(:voucher, is_unlimited: false, total_redemption_available: 100, redeemed_count: 100) }

        it 'returns false' do
          expect(voucher.has_quota_remaining?).to be false
        end
      end

      context 'with quota exceeded' do
        let(:voucher) { build(:voucher, is_unlimited: false, total_redemption_available: 100, redeemed_count: 150) }

        it 'returns false' do
          expect(voucher.has_quota_remaining?).to be false
        end
      end
    end
  end
end
