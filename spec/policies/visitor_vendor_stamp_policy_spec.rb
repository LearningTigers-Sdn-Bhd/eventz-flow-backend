require 'rails_helper'

RSpec.describe VisitorVendorStampPolicy, type: :policy do
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:event_admin) { create(:user, role: :member) }
  let(:event_team_member) { create(:user, role: :member) }
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:other_vendor) { create(:user, role: :vendor) }
  let(:random_user) { create(:user, role: :member) }

  let(:event) { create(:event, use_ticket: false) }
  let!(:event_vendor) { create(:event_vendor, event: event, vendor: vendor_user) }
  let!(:other_event_vendor) { create(:event_vendor, event: event, vendor: other_vendor) }
  let(:visitor) { create(:visitor, event: event) }

  before do
    create(:event_assignment, user: event_admin, event: event, role: :event_admin)
    create(:event_assignment, user: event_team_member, event: event, role: :event_team_member)
  end

  describe VisitorVendorStampPolicy::Scope do
    subject { described_class.new(user, VisitorVendorStamp.all).resolve }

    let!(:vendor_stamp) { create(:visitor_vendor_stamp, visitor: visitor, event_vendor: event_vendor) }
    let!(:other_vendor_stamp) { create(:visitor_vendor_stamp, visitor: visitor, event_vendor: other_event_vendor) }

    context 'when user is org_owner' do
      let(:user) { org_owner }

      it 'returns all stamps' do
        expect(subject).to include(vendor_stamp, other_vendor_stamp)
      end
    end

    context 'when user is organizer' do
      let(:user) { organizer }

      it 'returns all stamps' do
        expect(subject).to include(vendor_stamp, other_vendor_stamp)
      end
    end

    context 'when user is vendor' do
      let(:user) { vendor_user }

      it 'returns only their own stamps' do
        expect(subject).to include(vendor_stamp)
        expect(subject).not_to include(other_vendor_stamp)
      end
    end

    context 'when user is other vendor' do
      let(:user) { other_vendor }

      it 'returns only their own stamps' do
        expect(subject).to include(other_vendor_stamp)
        expect(subject).not_to include(vendor_stamp)
      end
    end

    context 'when user is random member' do
      let(:user) { random_user }

      it 'returns no stamps' do
        expect(subject).to be_empty
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns no stamps' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#index?' do
    context 'when user is org_owner' do
      subject { described_class.new(org_owner, event).index? }
      it { is_expected.to be true }
    end

    context 'when user is organizer' do
      subject { described_class.new(organizer, event).index? }
      it { is_expected.to be true }
    end

    context 'when user is event_admin' do
      subject { described_class.new(event_admin, event).index? }
      it { is_expected.to be true }
    end

    context 'when user is event_team_member' do
      subject { described_class.new(event_team_member, event).index? }
      it { is_expected.to be true }
    end

    context 'when user is vendor assigned to event' do
      subject { described_class.new(vendor_user, event).index? }
      it { is_expected.to be true }
    end

    context 'when user is vendor not assigned to event' do
      let(:unassigned_vendor) { create(:user, role: :vendor) }
      subject { described_class.new(unassigned_vendor, event).index? }
      it { is_expected.to be false }
    end

    context 'when user is random member' do
      subject { described_class.new(random_user, event).index? }
      it { is_expected.to be false }
    end

    context 'when user is nil' do
      subject { described_class.new(nil, event).index? }
      it { is_expected.to be false }
    end
  end

  describe '#create?' do
    context 'when user is org_owner' do
      subject { described_class.new(org_owner, event_vendor).create? }
      it { is_expected.to be true }
    end

    context 'when user is organizer' do
      subject { described_class.new(organizer, event_vendor).create? }
      it { is_expected.to be true }
    end

    context 'when user is event_admin' do
      subject { described_class.new(event_admin, event_vendor).create? }
      it { is_expected.to be true }
    end

    context 'when user is event_team_member' do
      subject { described_class.new(event_team_member, event_vendor).create? }
      it { is_expected.to be true }
    end

    context 'when vendor creates stamp for themselves' do
      subject { described_class.new(vendor_user, event_vendor).create? }
      it { is_expected.to be true }
    end

    context 'when vendor tries to create stamp for another vendor' do
      subject { described_class.new(vendor_user, other_event_vendor).create? }
      it { is_expected.to be false }
    end

    context 'when user is random member' do
      subject { described_class.new(random_user, event_vendor).create? }
      it { is_expected.to be false }
    end

    context 'when user is nil' do
      subject { described_class.new(nil, event_vendor).create? }
      it { is_expected.to be false }
    end
  end
end
