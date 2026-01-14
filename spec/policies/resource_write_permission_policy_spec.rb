# spec/policies/resource_permission_policy_spec.rb
require 'rails_helper'

RSpec.describe ResourceWritePermissionPolicy, type: :policy do
  subject { described_class }

  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let!(:write_permission) { create(:resource_write_permission, user: writer) }
  let(:regular_user) { create(:user, role: :member) }
  let(:visitor) { nil }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it "grants access to org owners" do
      expect(subject).to permit(org_owner)
    end

    it "denies access to writers" do
      expect(subject).not_to permit(writer)
    end

    it "denies access to regular users" do
      expect(subject).not_to permit(regular_user)
    end

    it "denies access to visitors" do
      expect(subject).not_to permit(visitor)
    end
  end
end
