# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventPolicy, type: :policy do
  describe '#view_email_status?' do
    let(:event) { create(:event) }

    it 'allows the org owner' do
      expect(described_class.new(create(:user, role: :org_owner), event).view_email_status?).to be true
    end

    it "allows the event's own admin" do
      user = create(:user, role: :organizer)
      create(:event_assignment, event: event, user: user, role: :event_admin)

      expect(described_class.new(user, event).view_email_status?).to be true
    end

    it 'rejects event team members' do
      user = create(:user, role: :member)
      create(:event_assignment, event: event, user: user, role: :event_team_member)

      expect(described_class.new(user, event).view_email_status?).to be false
    end

    it "rejects an admin of another event" do
      user = create(:user, role: :organizer)
      create(:event_assignment, event: create(:event), user: user, role: :event_admin)

      expect(described_class.new(user, event).view_email_status?).to be false
    end
  end
end
