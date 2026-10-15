# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventPolicy, type: :policy do
  describe '#rfid_admin?' do
    let(:event) { create(:event) }

    it 'allows the org owner' do
      expect(described_class.new(create(:user, role: :org_owner), event).rfid_admin?).to be true
    end

    it 'rejects an organizer and assigned event staff' do
      organizer = create(:user, role: :organizer)
      staff = create(:user, role: :member)
      create(:event_assignment, event: event, user: staff, role: :event_admin)

      expect(described_class.new(organizer, event).rfid_admin?).to be false
      expect(described_class.new(staff, event).rfid_admin?).to be false
    end

    it 'rejects no user' do
      expect(described_class.new(nil, event).rfid_admin?).to be false
    end
  end
end
