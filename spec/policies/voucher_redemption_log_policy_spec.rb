require 'rails_helper'

RSpec.describe VoucherRedemptionLogPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:vendor) { create(:user, :vendor) }
  let(:other_vendor) { create(:user, :vendor) }
  let(:organizer) { create(:user, :organizer) }
  let(:org_owner) { create(:user, :org_owner) }
  let(:member) { create(:user, :member) }

  let(:voucher) { create(:voucher, event: event, vendor: vendor) }
  let(:other_voucher) { create(:voucher, event: event, vendor: other_vendor) }
  let(:redemption_log) { create(:voucher_redemption_log, voucher: voucher) }
  let(:other_redemption_log) { create(:voucher_redemption_log, voucher: other_voucher) }

  describe VoucherRedemptionLogPolicy::Scope do
    subject { described_class.new(user, VoucherRedemptionLog.all).resolve }

    before do
      redemption_log
      other_redemption_log
    end

    context 'when user is org_owner' do
      let(:user) { org_owner }

      it 'returns all redemption logs' do
        expect(subject).to include(redemption_log, other_redemption_log)
      end
    end

    context 'when user is organizer' do
      let(:user) { organizer }

      it 'returns all redemption logs' do
        expect(subject).to include(redemption_log, other_redemption_log)
      end
    end

    context 'when user is vendor' do
      let(:user) { vendor }

      it 'returns only their own redemption logs' do
        expect(subject).to include(redemption_log)
        expect(subject).not_to include(other_redemption_log)
      end
    end

    context 'when user is member' do
      let(:user) { member }

      it 'returns no redemption logs' do
        expect(subject).to be_empty
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns no redemption logs' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#index?' do
    subject { described_class.new(user, VoucherRedemptionLog).index? }

    context 'when user is org_owner' do
      let(:user) { org_owner }
      it { is_expected.to be true }
    end

    context 'when user is organizer' do
      let(:user) { organizer }
      it { is_expected.to be true }
    end

    context 'when user is vendor' do
      let(:user) { vendor }
      it { is_expected.to be true }
    end

    context 'when user is member' do
      let(:user) { member }
      it { is_expected.to be false }
    end
  end

  describe '#view_redemption_logs?' do
    context 'when user is org_owner' do
      subject { described_class.new(org_owner, event).view_redemption_logs? }
      it { is_expected.to be true }
    end

    context 'when user is organizer' do
      subject { described_class.new(organizer, event).view_redemption_logs? }
      it { is_expected.to be true }
    end

    context 'when user is vendor' do
      subject { described_class.new(vendor, event).view_redemption_logs? }
      it { is_expected.to be true }
    end

    context 'when user is event_admin' do
      let(:event_admin) { create(:user, :member) }

      before do
        allow(event_admin).to receive(:is_event_admin?).with(event).and_return(true)
      end

      subject { described_class.new(event_admin, event).view_redemption_logs? }
      it { is_expected.to be true }
    end

    context 'when user is member without event_admin role' do
      subject { described_class.new(member, event).view_redemption_logs? }
      it { is_expected.to be false }
    end
  end
end
