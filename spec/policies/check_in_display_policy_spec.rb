# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInDisplayPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:display) { create(:check_in_display, event: event) }

  # Users
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:vendor) { create(:user, :vendor) }
  let(:event_admin) { create(:user, :member) }
  let(:event_team_member) { create(:user, :member) }

  before do
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
    create(:event_assignment, event: event, user: event_team_member, role: :event_team_member)
  end

  describe 'show?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, display).show?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, display).show?).to be true
    end

    it 'allows event_admin' do
      expect(described_class.new(event_admin, display).show?).to be true
    end

    it 'allows event_team_member' do
      expect(described_class.new(event_team_member, display).show?).to be true
    end

    it 'denies regular member not assigned to event' do
      expect(described_class.new(member, display).show?).to be false
    end

    it 'denies vendor' do
      expect(described_class.new(vendor, display).show?).to be false
    end

    it 'denies nil user' do
      expect(described_class.new(nil, display).show?).to be false
    end
  end

  describe 'update?' do
    it 'allows org_owner' do
      expect(described_class.new(org_owner, display).update?).to be true
    end

    it 'allows organizer' do
      expect(described_class.new(organizer, display).update?).to be true
    end

    it 'allows event_admin' do
      expect(described_class.new(event_admin, display).update?).to be true
    end

    it 'allows event_team_member' do
      expect(described_class.new(event_team_member, display).update?).to be true
    end

    it 'denies regular member not assigned to event' do
      expect(described_class.new(member, display).update?).to be false
    end

    it 'denies vendor' do
      expect(described_class.new(vendor, display).update?).to be false
    end
  end

  describe 'with unsaved record (build_check_in_display)' do
    let(:unsaved_display) { event.build_check_in_display }

    it 'allows org_owner to show unsaved display' do
      expect(described_class.new(org_owner, unsaved_display).show?).to be true
    end

    it 'allows event_admin to update unsaved display' do
      expect(described_class.new(event_admin, unsaved_display).update?).to be true
    end

    it 'denies member for unsaved display' do
      expect(described_class.new(member, unsaved_display).show?).to be false
    end
  end
end
