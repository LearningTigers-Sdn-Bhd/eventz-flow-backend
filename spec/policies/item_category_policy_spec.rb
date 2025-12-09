require 'rails_helper'

RSpec.describe ItemCategoryPolicy, type: :policy do
  let(:item_category) { create(:item_category) }

  subject { described_class.new(user, item_category) }

  context 'for an admin (org_owner)' do
    let(:user) { create(:user, :org_owner) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an organizer' do
    let(:user) { create(:user, :organizer) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  context 'for an exhibition contractor' do
    let(:user) { create(:user, :exhibition_contractor) }

    it { is_expected.to permit_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create update destroy]) }
  end

  context 'for other users' do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions(%i[index show create update destroy]) }
  end

  describe "scope" do
    let(:user) { create(:user, :org_owner) }
    let!(:item_category1) { create(:item_category) }
    let!(:item_category2) { create(:item_category) }

    it "returns all item categories for an org_owner" do
      expect(Pundit.policy_scope(user, ItemCategory).to_a).to match_array([item_category1, item_category2])
    end
  end
end
