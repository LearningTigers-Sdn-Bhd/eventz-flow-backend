require 'rails_helper'

RSpec.describe ExhibitionContractorProfilePolicy, type: :policy do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibition_contractor_user) { create(:user, :exhibition_contractor) }
  let(:member_user) { create(:user, :member) }

  let(:exhibition_contractor_profile_instance) { create(:exhibition_contractor_profile, user: exhibition_contractor_user) }
  let(:another_contractor_user) { create(:user, :exhibition_contractor) }
  let(:another_contractor_profile_instance) { create(:exhibition_contractor_profile, user: another_contractor_user) }

  # Test for show?
  describe "#show?" do
    it "grants access to org_owner" do
      expect(described_class.new(org_owner, exhibition_contractor_profile_instance)).to permit_action(:show)
    end

    it "grants access to organizer" do
      expect(described_class.new(organizer, exhibition_contractor_profile_instance)).to permit_action(:show)
    end

    it "grants access to exhibition_contractor for their own profile" do
      expect(described_class.new(exhibition_contractor_user, exhibition_contractor_profile_instance)).to permit_action(:show)
    end

    it "denies access to exhibition_contractor for another profile" do
      expect(described_class.new(exhibition_contractor_user, another_contractor_profile_instance)).to forbid_action(:show)
    end

    it "denies access to member" do
      expect(described_class.new(member_user, exhibition_contractor_profile_instance)).to forbid_action(:show)
    end
  end

  # Test for update?
  describe "#update?" do
    it "grants access to org_owner" do
      expect(described_class.new(org_owner, exhibition_contractor_profile_instance)).to permit_action(:update)
    end

    context "organizer access" do
      let(:creating_organizer) { create(:user, :organizer) }
      let(:other_organizer) { create(:user, :organizer) }
      let(:contractor_created_by_organizer) { create(:user, :exhibition_contractor, created_by: creating_organizer) }
      let(:profile_created_by_organizer) { create(:exhibition_contractor_profile, user: contractor_created_by_organizer) }

      it "grants access to organizer who created the contractor" do
        expect(described_class.new(creating_organizer, profile_created_by_organizer)).to permit_action(:update)
      end

      it "denies access to organizer who did not create the contractor" do
        expect(described_class.new(other_organizer, profile_created_by_organizer)).to forbid_action(:update)
      end
    end

    it "grants access to exhibition_contractor for their own profile" do
      expect(described_class.new(exhibition_contractor_user, exhibition_contractor_profile_instance)).to permit_action(:update)
    end

    it "denies access to exhibition_contractor for another profile" do
      expect(described_class.new(exhibition_contractor_user, another_contractor_profile_instance)).to forbid_action(:update)
    end

    it "denies access to member" do
      expect(described_class.new(member_user, exhibition_contractor_profile_instance)).to forbid_action(:update)
    end
  end
end