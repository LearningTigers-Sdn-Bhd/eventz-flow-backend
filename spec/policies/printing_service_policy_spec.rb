require 'rails_helper'

RSpec.describe PrintingServicePolicy, type: :policy do
  let(:item_category) { create(:item_category) }
  let(:printing_service) { create(:printing_service, item_category: item_category, user: creator_user) }
  let(:another_printing_service) { create(:printing_service, item_category: item_category) }

  subject { described_class.new(user, printing_service) }

  context 'for an admin (org_owner)' do
    let(:user) { create(:user, :org_owner) }
    let(:creator_user) { create(:user) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:printing_service) }
      let!(:item2) { create(:printing_service) }

      it "returns all printing services" do
        expect(Pundit.policy_scope(user, PrintingService).to_a).to match_array([item1, item2])
      end
    end
  end

  context 'for an organizer' do
    let(:user) { create(:user, :organizer) }
    let(:creator_user) { create(:user) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:printing_service) }
      let!(:item2) { create(:printing_service) }

      it "returns all printing services" do
        expect(Pundit.policy_scope(user, PrintingService).to_a).to match_array([item1, item2])
      end
    end
  end

  context 'for an exhibition contractor' do
    let(:user) { create(:user, :exhibition_contractor) }
    let(:creator_user) { user } # Contractor creates the item

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
    it { is_expected.to forbid_action(:destroy).with(another_printing_service) }

    describe "scope" do
      let!(:item_by_contractor) { create(:printing_service, user: user) }
      let!(:item_by_other_user) { create(:printing_service) }

      it "returns only items created by the contractor" do
        expect(Pundit.policy_scope(user, PrintingService).to_a).to match_array([item_by_contractor])
      end
    end
  end

  context 'for other users' do
    let(:user) { create(:user) }
    let(:creator_user) { create(:user) }

    it { is_expected.to forbid_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:printing_service) }
      let!(:item2) { create(:printing_service) }

      it "returns no printing services" do
        expect(Pundit.policy_scope(user, PrintingService).to_a).to be_empty
      end
    end
  end
end
