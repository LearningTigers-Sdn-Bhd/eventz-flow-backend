require 'rails_helper'

RSpec.describe ExhibitorKitPolicy, type: :policy do
  subject { described_class.new(user, exhibitor_kit) }

  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:exhibitor_user) { create(:user, :exhibitor) }
  let(:event_vendor) { create(:exhibitor, event: event, vendor: exhibitor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: event_vendor) }

  context 'for an admin' do
    let(:user) { create(:user, :org_owner) }

    it { is_expected.to permit_actions(%i[show create update destroy]) }
    it { is_expected.to permit_mass_assignment_of(:booth_number).for_action(:create) }
    it { is_expected.to permit_mass_assignment_of(:booth_number).for_action(:update) }
    it { is_expected.to forbid_mass_assignment_of(:exhibitor_booth_price_id).for_action(:update) }
    it { is_expected.to forbid_mass_assignment_of(:booth_type).for_action(:update) }
    it { is_expected.to forbid_mass_assignment_of(:booth_quantity).for_action(:update) }
    it { is_expected.to permit_mass_assignment_of(:amount_paid).for_action(:update) }
    it { is_expected.to permit_mass_assignment_of(:payment_status).for_action(:update) }
    it { is_expected.to permit_action(:download_ic_copy) }
  end

  context 'for an event contractor' do
    let(:user) { create(:user, :exhibition_contractor, with_profile: true) } # Ensure profile exists
    let!(:contractor_profile) { user.reload.exhibition_contractor_profile } # Use the one created with the user
    let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }

    it { is_expected.to permit_actions(%i[show update]) }
    it { is_expected.to forbid_action(:download_ic_copy) }
    it { is_expected.to forbid_actions(%i[create destroy]) }
    it { is_expected.to forbid_mass_assignment_of(:booth_number).for_action(:update) }
    it { is_expected.to forbid_mass_assignment_of(:payment_status).for_action(:update) }
  end

  context 'for an exhibitor' do
    let(:user) { exhibitor_user }

    it { is_expected.to permit_actions(%i[show update]) }
    it { is_expected.to forbid_action(:destroy) }
    it { is_expected.to forbid_action(:download_ic_copy) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_mass_assignment_of(:booth_number).for_action(:create) }
    it { is_expected.to forbid_mass_assignment_of(:booth_number).for_action(:update) }
    it { is_expected.to forbid_mass_assignment_of(:payment_status).for_action(:update) }
  end

  context 'for a user who is not part of the event' do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions(%i[show create update destroy]) }
  end
end
