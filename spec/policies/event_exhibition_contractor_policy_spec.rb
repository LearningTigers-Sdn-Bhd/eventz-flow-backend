require 'rails_helper'

RSpec.describe EventExhibitionContractorPolicy, type: :policy do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibition_contractor_user) { create(:user, :exhibition_contractor) }
  let(:member_user) { create(:user, :member) }

  let(:event) { create(:event) }
  let(:exhibition_contractor_profile) { create(:exhibition_contractor_profile, user: exhibition_contractor_user) }
  let(:event_exhibition_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: exhibition_contractor_profile) }

  # Test for index?
  describe "#index?" do
    context "when user is org_owner" do
      let(:user) { org_owner }
      it { expect(described_class.new(user, event_exhibition_contractor)).to permit_action(:index) }
    end

    context "when user is organizer" do
      let(:user) { organizer }
      it { expect(described_class.new(user, event_exhibition_contractor)).to permit_action(:index) }
    end

    context "when user is exhibition_contractor" do
      let(:user) { exhibition_contractor_user }
      it { expect(described_class.new(user, event_exhibition_contractor)).to permit_action(:index) }
    end

    context "when user is member" do
      let(:user) { member_user }
      it { expect(described_class.new(user, event_exhibition_contractor)).to forbid_action(:index) }
    end
  end

  # Test for create?
  describe "#create?" do
    context "when user is org_owner" do
      let(:user) { org_owner }
      it { expect(described_class.new(user, EventExhibitionContractor)).to permit_action(:create) }
    end

    context "when user is organizer" do
      let(:user) { organizer }
      it { expect(described_class.new(user, EventExhibitionContractor)).to permit_action(:create) }
    end

    context "when user is exhibition_contractor" do
      let(:user) { exhibition_contractor_user }
      it { expect(described_class.new(user, EventExhibitionContractor)).to forbid_action(:create) }
    end

    context "when user is member" do
      let(:user) { member_user }
      it { expect(described_class.new(user, EventExhibitionContractor)).to forbid_action(:create) }
    end
  end

  # Test for destroy?
  describe "#destroy?" do
    context "when user is org_owner" do
      let(:user) { org_owner }
      it { expect(described_class.new(user, event_exhibition_contractor)).to permit_action(:destroy) }
    end

    context "when user is organizer" do
      let(:user) { organizer }
      it { expect(described_class.new(user, event_exhibition_contractor)).to permit_action(:destroy) }
    end

    context "when user is exhibition_contractor" do
      let(:user) { exhibition_contractor_user }
      it { expect(described_class.new(user, event_exhibition_contractor)).to forbid_action(:destroy) }
    end

    context "when user is member" do
      let(:user) { member_user }
      it { expect(described_class.new(user, event_exhibition_contractor)).to forbid_action(:destroy) }
    end
  end

  # Test for .scope
  context "Scope" do
    let!(:other_event) { create(:event) }
    let!(:other_exhibition_contractor_profile) { create(:exhibition_contractor_profile) }
    let!(:assigned_event_exhibition_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: exhibition_contractor_profile) }
    let!(:other_assigned_event_exhibition_contractor) { create(:event_exhibition_contractor, event: other_event, exhibition_contractor_profile: other_exhibition_contractor_profile) }

    it "org_owner can see all event exhibition contractors" do
      resolved_scope = EventExhibitionContractorPolicy::Scope.new(org_owner, EventExhibitionContractor.all).resolve
      expect(resolved_scope).to contain_exactly(assigned_event_exhibition_contractor, other_assigned_event_exhibition_contractor)
    end

    it "organizer can see all event exhibition contractors" do
      resolved_scope = EventExhibitionContractorPolicy::Scope.new(organizer, EventExhibitionContractor.all).resolve
      expect(resolved_scope).to contain_exactly(assigned_event_exhibition_contractor, other_assigned_event_exhibition_contractor)
    end

    it "exhibition_contractor can only see their own assigned event exhibition contractors" do
      resolved_scope = EventExhibitionContractorPolicy::Scope.new(exhibition_contractor_user, EventExhibitionContractor.all).resolve
      expect(resolved_scope).to contain_exactly(assigned_event_exhibition_contractor)
    end

    it "member cannot see any event exhibition contractors" do
      resolved_scope = EventExhibitionContractorPolicy::Scope.new(member_user, EventExhibitionContractor.all).resolve
      expect(resolved_scope).to be_empty
    end
  end
end