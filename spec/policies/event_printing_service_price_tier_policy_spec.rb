require 'rails_helper'

RSpec.describe EventPrintingServicePriceTierPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:printing_service) { create(:printing_service) }
  let(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }
  let(:record) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service) }

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
    let(:other_event) { create(:event) }
    let(:other_printing_service) { create(:printing_service) }
    let(:event_printing_service_other) { create(:event_printing_service, event: other_event, printing_service: other_printing_service) }

    let!(:price_tier_1) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service) }
    let!(:price_tier_2) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service_other) }

    context 'for an admin (org_owner)' do
      let(:user) { create(:user, :org_owner) }
      it 'returns all event printing service price tiers' do
        expect(Pundit.policy_scope(user, EventPrintingServicePriceTier).to_a).to match_array([price_tier_1, price_tier_2])
      end
    end

    context 'for an organizer' do
      let(:user) { create(:user, :organizer) }
      it 'returns all event printing service price tiers' do
        expect(Pundit.policy_scope(user, EventPrintingServicePriceTier).to_a).to match_array([price_tier_1, price_tier_2])
      end
    end

    context 'for event staff' do
      let(:event_staff_user) { create(:user) }
      let(:staffed_event) { create(:event) }
      let!(:event_assignment) { create(:event_assignment, user: event_staff_user, event: staffed_event, role: :event_admin) }
      let!(:staffed_event_printing_service) { create(:event_printing_service, event: staffed_event) }
      let!(:staffed_price_tier) { create(:event_printing_service_price_tier, event_printing_service: staffed_event_printing_service) }
      let(:user) { event_staff_user }

      it 'returns price tiers for assigned events' do
        expect(Pundit.policy_scope(user, EventPrintingServicePriceTier).to_a).to match_array([staffed_price_tier])
      end
    end

    context 'for an exhibition contractor assigned to events' do
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
      let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
      let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
      let(:user) { contractor_user }

      it 'returns price tiers for assigned events' do
        expect(Pundit.policy_scope(user, EventPrintingServicePriceTier).to_a).to match_array([price_tier_1])
      end
    end

    context 'for other users' do
      it 'returns no event printing service price tiers' do
        expect(Pundit.policy_scope(create(:user), EventPrintingServicePriceTier).to_a).to be_empty
      end
    end
  end
end
