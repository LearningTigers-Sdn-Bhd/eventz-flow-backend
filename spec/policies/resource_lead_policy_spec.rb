# spec/policies/resource_lead_policy_spec.rb
require 'rails_helper'

RSpec.describe ResourceLeadPolicy, type: :policy do
  subject { described_class }

  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let!(:write_permission) { create(:resource_write_permission, user: writer) }
  let(:regular_user) { create(:user, role: :member) }
  let(:visitor) { nil }

  permissions :index?, :show?, :metrics? do
    it "grants access to org owners" do
      expect(subject).to permit(org_owner)
    end

    it "denies access to writers, regular users, and visitors" do
      expect(subject).not_to permit(writer)
      expect(subject).not_to permit(regular_user)
      expect(subject).not_to permit(visitor)
    end
  end

  permissions :create? do
    it "grants access to everyone" do
      expect(subject).to permit(org_owner)
      expect(subject).to permit(writer)
      expect(subject).to permit(regular_user)
      expect(subject).to permit(visitor)
    end
  end
end
