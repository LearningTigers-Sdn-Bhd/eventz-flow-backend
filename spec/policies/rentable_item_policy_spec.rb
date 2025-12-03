require 'rails_helper'

RSpec.describe RentableItemPolicy, type: :policy do
  let(:item_category) { create(:item_category) }
  let(:rentable_item) { create(:rentable_item, item_category: item_category, user: creator_user) }
  let(:another_rentable_item) { create(:rentable_item, item_category: item_category) }

  subject { described_class.new(user, rentable_item) }

  context 'for an admin (org_owner)' do
    let(:user) { create(:user, :org_owner) }
    let(:creator_user) { create(:user) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:rentable_item) }
      let!(:item2) { create(:rentable_item) }

      it "returns all rentable items" do
        expect(Pundit.policy_scope(user, RentableItem).to_a).to match_array([item1, item2])
      end
    end
  end

  context 'for an organizer' do
    let(:user) { create(:user, :organizer) }
    let(:creator_user) { create(:user) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:rentable_item) }
      let!(:item2) { create(:rentable_item) }

      it "returns all rentable items" do
        expect(Pundit.policy_scope(user, RentableItem).to_a).to match_array([item1, item2])
      end
    end
  end

  context 'for an exhibition contractor' do
    let(:user) { create(:user, :exhibition_contractor) }
    let(:creator_user) { user } # Contractor creates the item

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
    it { is_expected.to forbid_action(:destroy).with(another_rentable_item) }

    describe "scope" do
      let!(:item_by_contractor) { create(:rentable_item, user: user) }
      let!(:item_by_other_user) { create(:rentable_item) }

      it "returns only items created by the contractor" do
        expect(Pundit.policy_scope(user, RentableItem).to_a).to match_array([item_by_contractor])
      end
    end
  end

  context 'for other users' do
    let(:user) { create(:user) }
    let(:creator_user) { create(:user) }

    it { is_expected.to forbid_actions(%i[index show create update destroy]) }

    describe "scope" do
      let!(:item1) { create(:rentable_item) }
      let!(:item2) { create(:rentable_item) }

      it "returns no rentable items" do
        expect(Pundit.policy_scope(user, RentableItem).to_a).to be_empty
      end
    end
  end
end
