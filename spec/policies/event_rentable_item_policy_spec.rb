require 'rails_helper'

RSpec.describe EventRentableItemPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:rentable_item) { create(:rentable_item) }
  let(:record) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }

  subject { described_class.new(user, record) }

  context 'for an admin (org_owner)' do
    let(:user) { create(:user, :org_owner) }
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an organizer' do
    let(:user) { create(:user, :organizer) }
    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for event staff' do
    let(:event_admin) { create(:user) }
    let!(:event_assignment) { create(:event_assignment, user: event_admin, event: event, role: :event_admin) }
    let(:user) { event_admin }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibition contractor assigned to the event' do
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
    let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
    let(:user) { contractor_user }

    it { is_expected.to permit_actions(%i[index show create update destroy]) } # Changed to permit
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
    let!(:event_rentable_item_1) { create(:event_rentable_item) }
    let!(:event_rentable_item_2) { create(:event_rentable_item) }

    context 'for an admin (org_owner)' do
      let(:user) { create(:user, :org_owner) }
      it 'returns all event rentable items' do
        expect(Pundit.policy_scope(user, EventRentableItem).to_a).to match_array([event_rentable_item_1, event_rentable_item_2])
      end
    end

    context 'for an organizer' do
      let(:user) { create(:user, :organizer) }
      it 'returns all event rentable items' do
        expect(Pundit.policy_scope(user, EventRentableItem).to_a).to match_array([event_rentable_item_1, event_rentable_item_2])
      end
    end

    context 'for event staff' do
      let(:event_staff_user) { create(:user) }
      let(:staffed_event) { create(:event) }
      let!(:event_assignment) { create(:event_assignment, user: event_staff_user, event: staffed_event, role: :event_admin) }
      let!(:staffed_event_rentable_item) { create(:event_rentable_item, event: staffed_event) }
      let(:user) { event_staff_user }

      it 'returns event rentable items for assigned events' do
        expect(Pundit.policy_scope(user, EventRentableItem).to_a).to match_array([staffed_event_rentable_item])
      end
    end

    context 'for an exhibition contractor assigned to events' do
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
      let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
      let(:contractor_event) { create(:event) }
      let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: contractor_event, exhibition_contractor_profile: contractor_profile) }
      let!(:contractor_event_rentable_item) { create(:event_rentable_item, event: contractor_event) }
      let(:user) { contractor_user }

      it 'returns event rentable items for assigned events' do
        expect(Pundit.policy_scope(user, EventRentableItem).to_a).to match_array([contractor_event_rentable_item])
      end
    end

    context 'for other users' do
      it 'returns no event rentable items' do
        expect(Pundit.policy_scope(create(:user), EventRentableItem).to_a).to be_empty
      end
    end

    context 'for an exhibitor' do
      let(:exhibitor_user) { create(:user, :exhibitor) }
      let(:exhibitor_event) { create(:event) }
      let(:event_vendor_exhibitor) { create(:exhibitor, event: exhibitor_event, vendor: exhibitor_user) }
      let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: event_vendor_exhibitor) }
      let!(:exhibitor_item_active) { create(:event_rentable_item, event: exhibitor_event, rentable_item: create(:rentable_item, status: :active)) }
      let!(:exhibitor_item_inactive) { create(:event_rentable_item, event: exhibitor_event, rentable_item: create(:rentable_item, status: :inactive)) }
      let(:user) { exhibitor_user }

      it 'returns only active event rentable items for their assigned events' do
        expect(Pundit.policy_scope(user, EventRentableItem).to_a).to match_array([exhibitor_item_active])
      end
    end
  end
end
