require 'rails_helper'

RSpec.describe ExhibitorKitItemPolicy, type: :policy do
  # Common setup for all contexts
  let(:base_user) { create(:user) }
  let(:base_event) { create(:event) }
  let(:base_exhibitor_user) { create(:user, :exhibitor) } # A user with :exhibitor role
  let(:base_event_vendor) { create(:exhibitor, event: base_event, vendor: base_exhibitor_user) } # An Exhibitor EventVendor
  let(:base_exhibitor_kit) { create(:exhibitor_kit, event_vendor: base_event_vendor) } # An ExhibitorKit
  let(:base_rentable_item) { create(:rentable_item, status: :active) } # An active RentableItem
  let!(:base_event_rentable_item) { create(:event_rentable_item, event: base_event, rentable_item: base_rentable_item) } # Link it to the event

  # The record being authorized for non-scope tests
  let(:record) { create(:exhibitor_kit_item, exhibitor_kit: base_exhibitor_kit, rentable_item: base_rentable_item) }

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
    let(:user) { base_exhibitor_user } # Use the base exhibitor user
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibition contractor assigned to the event' do
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
    let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: base_event, exhibition_contractor_profile: contractor_profile) }
    let(:user) { contractor_user }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibition contractor not assigned to the event' do
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
    let(:user) { contractor_user }

    it { is_expected.to forbid_actions(%i[index show create update destroy]) }
  end

  context 'for other users' do
    let(:user) { create(:user) } # Define user here
    it { is_expected.to forbid_actions(%i[index show create update destroy]) }
  end

  describe "scope" do
    # Common setup for scope tests
    let(:admin_user) { create(:user, :org_owner) }
    let(:organizer_user) { create(:user, :organizer) }
    let(:exhibitor_owner_user) { create(:user, :exhibitor) }
    let(:contractor_assigned_user) { create(:user, :exhibition_contractor, with_profile: true) } # Ensure profile exists
    let(:other_user) { create(:user) }

    # Exhibitor kit items for various scenarios
    let(:exhibitor_kit_for_owner) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: base_event, vendor: exhibitor_owner_user)) }
    let(:rentable_item_for_owner) { create(:rentable_item, status: :active) }
    let!(:event_rentable_item_for_owner) { create(:event_rentable_item, event: base_event, rentable_item: rentable_item_for_owner) }
    let!(:exhibitor_kit_item_owner) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit_for_owner, rentable_item: rentable_item_for_owner) }

    let(:contractor_event_for_scope) { create(:event) } # Create a specific event for contractor scope
          let!(:event_contractor_assignment_for_scope) { create(:event_exhibition_contractor, event: contractor_event_for_scope, exhibition_contractor_profile: contractor_assigned_user.reload.exhibition_contractor_profile) }
      let(:exhibitor_kit_for_contractor_event) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: contractor_event_for_scope, vendor: create(:user, :exhibitor))) }
    let(:rentable_item_for_contractor) { create(:rentable_item, status: :active) }
    let!(:event_rentable_item_for_contractor) { create(:event_rentable_item, event: contractor_event_for_scope, rentable_item: rentable_item_for_contractor) }
    let!(:exhibitor_kit_item_contractor_event) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit_for_contractor_event, rentable_item: rentable_item_for_contractor) }


    context 'for an admin (org_owner)' do
      let(:user) { admin_user }
      it 'returns all exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_owner, exhibitor_kit_item_contractor_event])
      end
    end

    context 'for an organizer' do
      let(:user) { organizer_user }
      it 'returns all exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_owner, exhibitor_kit_item_contractor_event])
      end
    end

    context 'for an exhibitor who owns the kit' do
      let(:user) { exhibitor_owner_user }
      it 'returns only their exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_owner])
      end
    end

    context 'for an exhibition contractor assigned to events' do
      let(:user) { contractor_assigned_user }
      it 'returns exhibitor kit items for assigned events' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to match_array([exhibitor_kit_item_contractor_event])
      end
    end

    context 'for other users' do
      let(:user) { other_user }
      it 'returns no exhibitor kit items' do
        expect(Pundit.policy_scope(user, ExhibitorKitItem).to_a).to be_empty
      end
    end
  end
end