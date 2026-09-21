# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventPolicy, type: :policy do
  describe '#view_activity_log?' do
    let(:event) { create(:event) }

    it 'allows assigned non-owner staff' do
      user = create(:user, role: :member)
      create(:event_assignment, event: event, user: user, role: :business_matching_admin)

      expect(described_class.new(user, event).view_activity_log?).to be true
    end

    it 'rejects an unassigned user' do
      outsider = create(:user, role: :member)

      expect(described_class.new(outsider, event).view_activity_log?).to be false
    end

    it 'allows the org owner even without an explicit event assignment' do
      owner = create(:user, role: :org_owner)

      expect(described_class.new(owner, event).view_activity_log?).to be true
    end
  end

  describe '#clear_activity_log?' do
    let(:event) { create(:event) }

    it 'allows the org owner' do
      owner = create(:user, role: :org_owner)

      expect(described_class.new(owner, event).clear_activity_log?).to be true
    end

    it 'rejects assigned non-owner staff' do
      user = create(:user, role: :member)
      create(:event_assignment, event: event, user: user, role: :event_admin)

      expect(described_class.new(user, event).clear_activity_log?).to be false
    end

    it 'rejects an unassigned user' do
      outsider = create(:user, role: :member)

      expect(described_class.new(outsider, event).clear_activity_log?).to be false
    end
  end
end
