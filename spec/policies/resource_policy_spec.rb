# spec/policies/resource_policy_spec.rb
require 'rails_helper'

RSpec.describe ResourcePolicy, type: :policy do
  subject { described_class }

  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let!(:write_permission) { create(:resource_write_permission, user: writer) }
  let(:other_writer) { create(:user, role: :member) }
  let!(:other_write_permission) { create(:resource_write_permission, user: other_writer) }
  
  let(:regular_user) { create(:user, role: :member) }
  let(:visitor) { nil }

  let!(:published_resource) { create(:resource, status: :published, user: writer) }
  let!(:draft_resource) { create(:resource, status: :draft, user: writer) }
  let!(:other_draft_resource) { create(:resource, status: :draft, user: other_writer) }

  permissions :index? do
    it "grants access to everyone" do
      expect(subject).to permit(org_owner)
      expect(subject).to permit(writer)
      expect(subject).to permit(regular_user)
      expect(subject).to permit(visitor)
    end
  end

  permissions :show? do
    it "grants access to everyone for published resources" do
      expect(subject).to permit(visitor, published_resource)
      expect(subject).to permit(regular_user, published_resource)
      expect(subject).to permit(writer, published_resource)
      expect(subject).to permit(org_owner, published_resource)
    end

    it "grants access to the author for their own draft resource" do
      expect(subject).to permit(writer, draft_resource)
    end

    it "grants access to org owners for any draft resource" do
      expect(subject).to permit(org_owner, draft_resource)
    end

    it "denies access to other writers for a draft resource" do
      expect(subject).not_to permit(other_writer, draft_resource)
    end

    it "denies access to regular users and visitors for draft resources" do
      expect(subject).not_to permit(regular_user, draft_resource)
      expect(subject).not_to permit(visitor, draft_resource)
    end
  end

  permissions :create? do
    it "grants access to org owners and writers" do
      expect(subject).to permit(org_owner)
      expect(subject).to permit(writer)
    end

    it "denies access to regular users and visitors" do
      expect(subject).not_to permit(regular_user)
      expect(subject).not_to permit(visitor)
    end
  end

  permissions :update?, :destroy?, :restore? do
    it "grants access to the author of the resource" do
      expect(subject).to permit(writer, draft_resource)
    end
    
    it "grants access to org owners for any resource" do
      expect(subject).to permit(org_owner, draft_resource)
    end

    it "denies access to other authors" do
      expect(subject).not_to permit(other_writer, draft_resource)
    end

    it "denies access to regular users" do
      expect(subject).not_to permit(regular_user, draft_resource)
    end
  end

  permissions :force_destroy?, :approval? do
    it "grants access only to org owners" do
      expect(subject).to permit(org_owner)
    end

    it "denies access to writers and regular users" do
      expect(subject).not_to permit(writer)
      expect(subject).not_to permit(regular_user)
    end
  end

  describe "Scope" do
    let(:scope) { ResourcePolicy::Scope.new(user, Resource.all).resolve }

    context "for org owners" do
      let(:user) { org_owner }
      
      it "includes draft and published resources" do
        expect(scope).to include(published_resource, draft_resource, other_draft_resource)
      end
    end

    context "for writers" do
      let(:user) { writer }

      it "includes published resources" do
        expect(scope).to include(published_resource)
      end

      it "includes own draft resources" do
        expect(scope).to include(draft_resource)
      end

      it "excludes other writers' draft resources" do
        expect(scope).not_to include(other_draft_resource)
      end
    end

    context "for regular users" do
      let(:user) { regular_user }

      it "includes only published resources" do
        expect(scope).to include(published_resource)
        expect(scope).not_to include(draft_resource)
        expect(scope).not_to include(other_draft_resource)
      end
    end

    context "for visitors" do
      let(:user) { nil }

      it "includes only published resources" do
        expect(scope).to include(published_resource)
        expect(scope).not_to include(draft_resource)
        expect(scope).not_to include(other_draft_resource)
      end
    end
  end
end
