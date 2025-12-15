require 'rails_helper'

RSpec.describe ExhibitorTeamMemberLimitPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:limit) { create(:exhibitor_team_member_limit, event: event) }

  # Users
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:vendor) { create(:user, :vendor) }
  let(:event_admin) { create(:user, :member) }

  before do
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
  end

  describe 'show?' do
    # Create a vendor user that is assigned to this event
    let(:event_vendor_user) { create(:user, :vendor) }
    
    before do
      # Assign vendor to event
      create(:exhibitor, event: event, vendor: event_vendor_user)
    end

    it 'allows org_owner' do
      expect(described_class.new(org_owner, limit).show?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, limit).show?).to be true
    end

    it 'allows event_admin' do
      expect(described_class.new(event_admin, limit).show?).to be true
    end

    it 'allows event vendor (exhibitor) to view' do
      expect(described_class.new(event_vendor_user, limit).show?).to be true
    end

    it 'denies regular member not assigned to event' do
      expect(described_class.new(member, limit).show?).to be false
    end

    it 'denies vendor not assigned to this event' do
      unassigned_vendor = create(:user, :vendor)
      expect(described_class.new(unassigned_vendor, limit).show?).to be false
    end
  end

  describe 'create?' do
    # Build a new limit for a different event to test create
    let(:new_event) { create(:event) }
    let(:new_limit) { build(:exhibitor_team_member_limit, event: new_event) }

    before do
      create(:event_assignment, event: new_event, user: event_admin, role: :event_admin)
    end

    it 'allows org_owner' do
      expect(described_class.new(org_owner, new_limit).create?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, new_limit).create?).to be true
    end

    it 'allows event_admin for their event' do
      expect(described_class.new(event_admin, new_limit).create?).to be true
    end

    it 'denies regular member' do
      expect(described_class.new(member, new_limit).create?).to be false
    end
  end

  describe 'update?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, limit).update?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, limit).update?).to be true
    end

    it 'allows event_admin' do
      expect(described_class.new(event_admin, limit).update?).to be true
    end

    it 'denies regular member' do
      expect(described_class.new(member, limit).update?).to be false
    end
  end

  describe 'destroy?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, limit).destroy?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, limit).destroy?).to be true
    end

    it 'allows event_admin' do
      expect(described_class.new(event_admin, limit).destroy?).to be true
    end

    it 'denies regular member' do
      expect(described_class.new(member, limit).destroy?).to be false
    end
  end
end
