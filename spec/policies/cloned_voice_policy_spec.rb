require 'rails_helper'

RSpec.describe ClonedVoicePolicy, type: :policy do
  let(:group) { create(:group) }
  let(:event) { create(:event) }
  let(:other_event) { create(:event) }
  
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) { create(:user, :member) }
  let(:other_event_admin) { create(:user, :member) }
  let(:event_staff) { create(:user, :member) }
  let(:regular_member) { create(:user, :member) }

  let(:cloned_voice) { create(:cloned_voice, owner: event_admin, event: event, creator: event_admin) }

  before do
    # create(:group_member, group: group, user: organizer, has_manager_access: true) # Not needed anymore?
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
    create(:event_assignment, event: other_event, user: other_event_admin, role: :event_admin)
    create(:event_assignment, event: event, user: event_staff, role: :event_team_member)
  end

  describe 'index?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, ClonedVoice).index?).to be true
    end

    it 'allows regular member (as long as they are logged in, scope will filter)' do
      expect(described_class.new(regular_member, ClonedVoice).index?).to be true
    end
  end

  describe 'show?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, cloned_voice).show?).to be true
    end

    it 'allows event_admin of the same event' do
      expect(described_class.new(event_admin, cloned_voice).show?).to be true
    end

    it 'allows event_staff of the same event' do
      expect(described_class.new(event_staff, cloned_voice).show?).to be true
    end

    it 'denies other event_admin' do
      expect(described_class.new(other_event_admin, cloned_voice).show?).to be false
    end

    it 'denies regular member' do
      expect(described_class.new(regular_member, cloned_voice).show?).to be false
    end
  end

  describe 'create?' do
    it 'allows org_owner' do
      new_voice = build(:cloned_voice, owner: organizer, event: event)
      expect(described_class.new(org_owner, new_voice).create?).to be true
    end

    it 'allows event_admin for their event' do
      new_voice = build(:cloned_voice, owner: organizer, event: event)
      expect(described_class.new(event_admin, new_voice).create?).to be true
    end

    it 'denies event_admin for other event' do
      new_voice = build(:cloned_voice, owner: organizer, event: other_event)
      expect(described_class.new(event_admin, new_voice).create?).to be false
    end

    it 'denies regular staff' do
      new_voice = build(:cloned_voice, owner: organizer, event: event)
      expect(described_class.new(event_staff, new_voice).create?).to be false
    end
  end

  describe 'update?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, cloned_voice).update?).to be true
    end

    it 'allows creator event_admin' do
      expect(described_class.new(event_admin, cloned_voice).update?).to be true
    end

    it 'denies non-creator event_staff' do
      expect(described_class.new(event_staff, cloned_voice).update?).to be false
    end
  end

  describe 'Scope' do
    it 'returns all voices for org_owner' do
      cloned_voice # Trigger lazy load
      create(:cloned_voice, owner: organizer, event: event, creator: organizer)
      create(:cloned_voice, owner: organizer, event: other_event, creator: other_event_admin)
      expect(described_class::Scope.new(org_owner, ClonedVoice).resolve.count).to eq(3)
    end

    it 'returns only related voices for event_admin' do
      my_voice = cloned_voice
      other_voice = create(:cloned_voice, owner: other_event_admin, event: other_event)
      
      resolved = described_class::Scope.new(event_admin, ClonedVoice).resolve
      expect(resolved).to include(my_voice)
      expect(resolved).not_to include(other_voice)
    end
  end
end
