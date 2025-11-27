require 'rails_helper'

RSpec.describe ExhibitionContractorProfilePolicy, type: :policy do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibition_contractor_user) { create(:user, :exhibition_contractor) }
  let(:member_user) { create(:user, :member) }

  let(:exhibition_contractor_profile_instance) { create(:exhibition_contractor_profile, user: exhibition_contractor_user) }
  let(:another_contractor_profile_instance) { create(:exhibition_contractor_profile) }


  # Test for index?
  describe "#index?" do
    it "grants access to org_owner" do
      expect(described_class.new(org_owner, ExhibitionContractorProfile)).to permit_action(:index)
    end

    it "grants access to organizer" do
      expect(described_class.new(organizer, ExhibitionContractorProfile)).to permit_action(:index)
    end

    it "denies access to exhibition_contractor" do
      expect(described_class.new(exhibition_contractor_user, ExhibitionContractorProfile)).to forbid_action(:index)
    end

    it "denies access to member" do
      expect(described_class.new(member_user, ExhibitionContractorProfile)).to forbid_action(:index)
    end
  end

  # Test for create?
  describe "#create?" do
    it "grants access to org_owner" do
      expect(described_class.new(org_owner, ExhibitionContractorProfile)).to permit_action(:create)
    end

    it "grants access to organizer" do
      expect(described_class.new(organizer, ExhibitionContractorProfile)).to permit_action(:create)
    end

    it "denies access to exhibition_contractor" do
      expect(described_class.new(exhibition_contractor_user, ExhibitionContractorProfile)).to forbid_action(:create)
    end

    it "denies access to member" do
      expect(described_class.new(member_user, ExhibitionContractorProfile)).to forbid_action(:create)
    end
  end

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

    it "grants access to organizer" do
      expect(described_class.new(organizer, exhibition_contractor_profile_instance)).to permit_action(:update)
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

  # Test for destroy?
  describe "#destroy?" do
    it "grants access to org_owner" do
      expect(described_class.new(org_owner, exhibition_contractor_profile_instance)).to permit_action(:destroy)
    end

    it "grants access to organizer" do
      expect(described_class.new(organizer, exhibition_contractor_profile_instance)).to permit_action(:destroy)
    end

    it "denies access to exhibition_contractor" do
      expect(described_class.new(exhibition_contractor_user, exhibition_contractor_profile_instance)).to forbid_action(:destroy)
    end

    it "denies access to member" do
      expect(described_class.new(member_user, exhibition_contractor_profile_instance)).to forbid_action(:destroy)
    end
  end

  # Test for .scope
  context "Scope" do
    let!(:other_exhibition_contractor_profile) { create(:exhibition_contractor_profile) }
    let!(:users_exhibition_contractor_profile) { create(:exhibition_contractor_profile, user: exhibition_contractor_user) }

    it "org_owner can see all profiles" do
      resolved_scope = ExhibitionContractorProfilePolicy::Scope.new(org_owner, ExhibitionContractorProfile.all).resolve
      expect(resolved_scope).to contain_exactly(other_exhibition_contractor_profile, users_exhibition_contractor_profile)
    end

    it "organizer can see all profiles" do
      resolved_scope = ExhibitionContractorProfilePolicy::Scope.new(organizer, ExhibitionContractorProfile.all).resolve
      expect(resolved_scope).to contain_exactly(other_exhibition_contractor_profile, users_exhibition_contractor_profile)
    end

    it "exhibition_contractor can only see their own profile" do
      resolved_scope = ExhibitionContractorProfilePolicy::Scope.new(exhibition_contractor_user, ExhibitionContractorProfile.all).resolve
      expect(resolved_scope).to contain_exactly(users_exhibition_contractor_profile)
    end

    it "member cannot see any profiles" do
      resolved_scope = ExhibitionContractorProfilePolicy::Scope.new(member_user, ExhibitionContractorProfile.all).resolve
      expect(resolved_scope).to be_empty
    end
  end
end