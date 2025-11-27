require 'rails_helper'

RSpec.describe VoucherRedemptionLog, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:voucher) }
    it { is_expected.to belong_to(:redeemer) }
    it { is_expected.to belong_to(:redeemer_staff).class_name('User').with_foreign_key('redeemer_staff_id').optional }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:voucher) }
    it { is_expected.to validate_presence_of(:redeemer) }
    it { is_expected.to validate_presence_of(:redemption_timestamp) }
    it { is_expected.to validate_presence_of(:redemption_status) }
    it { is_expected.to validate_presence_of(:transaction_gross_amount) }
    it { is_expected.to validate_numericality_of(:transaction_gross_amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:discount_applied_value) }
    it { is_expected.to validate_numericality_of(:discount_applied_value).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:transaction_net_amount) }
    it { is_expected.to validate_numericality_of(:transaction_net_amount).is_greater_than_or_equal_to(0) }
  end

  describe 'Scopes' do
    let(:event) { create(:event) }
    let(:other_event) { create(:event) }
    let(:voucher) { create(:voucher, event: event) }
    let(:other_voucher) { create(:voucher, event: other_event) }
    let!(:log1) { create(:voucher_redemption_log, voucher: voucher, discount_applied_value: 10, transaction_net_amount: 90, redemption_timestamp: 1.day.ago) }
    let!(:log2) { create(:voucher_redemption_log, voucher: voucher, discount_applied_value: 20, transaction_net_amount: 80, redemption_timestamp: Time.current) }
    let!(:other_log) { create(:voucher_redemption_log, voucher: other_voucher) }

    describe '.for_event' do
      it 'returns logs for the given event' do
        expect(described_class.for_event(event)).to include(log1, log2)
        expect(described_class.for_event(event)).not_to include(other_log)
      end
    end

    describe '.total_discount_value' do
      it 'returns the sum of discount_applied_value' do
        expect(described_class.for_event(event).total_discount_value).to eq(30)
      end
    end

    describe '.total_sales' do
      it 'returns the sum of transaction_net_amount' do
        expect(described_class.for_event(event).total_sales).to eq(170)
      end
    end
    


    describe '.latest_redemption_transactions' do
      it 'returns latest logs ordered by timestamp' do
        latest = described_class.latest_redemption_transactions
        expect(latest.first).to eq(log2) # log2 is newer
      end
    end
  end

  describe 'Class Methods' do
    describe '.daily_redemption_trend' do
    let(:event) { create(:event) }
    let(:voucher) { create(:voucher, event: event) }
    let!(:log) { create(:voucher_redemption_log, voucher: voucher, redemption_timestamp: Time.current) }

    it 'returns formatted array of hashes' do
      result = described_class.daily_redemption_trend
      expect(result).to be_an(Array)
      expect(result.first).to have_key(:date)
      expect(result.first).to have_key(:count)
    end
    end

    describe '.top_scanned_vouchers' do
      let(:event) { create(:event) }
      let(:vendor) { create(:user, :vendor, full_name: 'Vendor One') }
      let(:voucher) { create(:voucher, event: event, vendor: vendor, title: 'Voucher A') }
      let!(:log1) { create(:voucher_redemption_log, voucher: voucher) }
      let!(:log2) { create(:voucher_redemption_log, voucher: voucher) }

      it 'returns top vouchers with detailed info' do
        results = described_class.top_scanned_vouchers
        expect(results).to be_an(Array)
        
        entry = results.find { |r| r[:voucher_id] == voucher.id }
        expect(entry).to be_present
        expect(entry[:voucher_title]).to eq('Voucher A')
        expect(entry[:vendor_name]).to eq('Vendor One')
        expect(entry[:redemption_count]).to eq(2)
      end
    end
  end

  describe '#as_json' do
    let(:voucher) { create(:voucher) }
    let(:redeemer) { create(:user) }
    let(:log) { create(:voucher_redemption_log, voucher: voucher, redeemer: redeemer) }

    it 'includes extra fields' do
      json = log.as_json
      expect(json).to include(:voucher_title, :voucher_code, :vendor_name, :redeemer_name, :redeemer_type)
    end
  end
end
