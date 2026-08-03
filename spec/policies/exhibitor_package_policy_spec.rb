require 'rails_helper'

RSpec.describe ExhibitorPackagePolicy do
  subject { described_class }

  let(:event) { create(:event) }
  let(:package) { create(:exhibitor_package, event: event) }
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:member) { create(:user, role: :member) }

  permissions :create?, :update?, :destroy? do
    it 'grants access to an org owner' do
      expect(subject).to permit(org_owner, package)
    end

    it 'grants access to an organizer' do
      expect(subject).to permit(organizer, package)
    end

    it 'denies an unrelated member' do
      expect(subject).not_to permit(member, package)
    end

    it 'grants access to event staff' do
      create(:event_assignment, user: member, event: event, role: :event_admin)

      expect(subject).to permit(member.reload, package)
    end
  end

  describe 'Scope' do
    it 'returns all packages for an organizer' do
      package

      expect(described_class::Scope.new(organizer, ExhibitorPackage).resolve).to include(package)
    end

    it 'returns only assigned events for a member' do
      package
      other = create(:exhibitor_package)
      create(:event_assignment, user: member, event: event, role: :event_team_member)

      resolved = described_class::Scope.new(member.reload, ExhibitorPackage).resolve

      expect(resolved).to include(package)
      expect(resolved).not_to include(other)
    end
  end
end
