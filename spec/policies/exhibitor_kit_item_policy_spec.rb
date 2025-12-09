require 'rails_helper'

RSpec.describe ExhibitorKitItemPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event, vendor: vendor_user)) }
  let(:rentable_item) { create(:rentable_item) }
  let(:record) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item) }

  subject { described_class.new(user, record) }

  context 'for an admin (org_owner)' do
    let(:user) { create(:user, :org_owner) }
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an organizer' do
    let(:user) { create(:user, :organizer) }
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibitor who owns the kit' do
    let(:user) { vendor_user } # The exhibitor_kit belongs to this user's event_vendor
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibition contractor assigned to the event' do
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
    let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
    let(:user) { contractor_user }

    it { is_expected.to permit_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create update destroy]) }
  end

  context 'for an exhibition contractor not assigned to the event' do
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
    let(:user) { contractor_user }

    it { is_expected.to forbid_actions(%i[index show create update destroy]) }
  end

  context 'for other users' do
    it { is_expected.to forbid_actions(%i[index show create update destroy]) }
  end

  describe "scope" do
    let(:other_event) { create(:event) }
    let(:other_vendor_user) { create(:user, :vendor) }
    let(:other_exhibitor_kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: other_event, vendor: other_vendor_user)) }

    let!(:exhibitor_kit_item_1) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit) }
    let!(:exhibitor_kit_item_2) { create(:exhibitor_kit_item, exhibitor_kit: other_exhibitor_kit) }

    context 'for an admin (org_owner)' do
      let(:user) { create(:user, :org_owner) }
      it 'returns all exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_1, exhibitor_kit_item_2])
      end
    end

    context 'for an organizer' do
      let(:user) { create(:user, :organizer) }
      it 'returns all exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_1, exhibitor_kit_item_2])
      end
    end

    context 'for an exhibitor who owns the kit' do
      let(:user) { vendor_user }
      it 'returns only their exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_1])
      end
    end

    context 'for an exhibition contractor assigned to events' do
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
      let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
      let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
      let(:user) { contractor_user }

      it 'returns exhibitor kit items for assigned events' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_1])
      end
    end

    context 'for other users' do
      it 'returns no exhibitor kit items' do
        expect(Pundit.policy_scope(create(:user), ExhibitorKitItem).to_a).to be_empty
      end
    end
  end
end
