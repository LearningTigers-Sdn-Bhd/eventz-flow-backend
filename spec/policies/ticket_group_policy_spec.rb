require 'rails_helper'

RSpec.describe TicketGroupPolicy, type: :policy do
  let(:event) { create(:event, published: false) }
  let(:group) { event.ticket_groups.create!(name: 'Room A', position: 1) }

  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) do
    create(:user, :member).tap { |u| create(:event_assignment, role: :event_admin, event: event, user: u) }
  end
  let(:team_member) do
    create(:user, :member).tap { |u| create(:event_assignment, role: :event_team_member, event: event, user: u) }
  end
  let(:outsider) { create(:user, :member) }

  let(:all_actions) { %i[index manage setup update destroy preview assign move] }

  it { expect(described_class.new(org_owner, group)).to permit_actions(all_actions) }
  it { expect(described_class.new(organizer, group)).to permit_actions(all_actions) }
  it { expect(described_class.new(event_admin, group)).to permit_actions(all_actions) }

  describe 'event team member: look only' do
    it { expect(described_class.new(team_member, group)).to permit_actions(%i[index]) }
    it { expect(described_class.new(team_member, group)).to forbid_actions(%i[manage setup update destroy preview assign move]) }
  end

  describe 'user with no access to the event' do
    it { expect(described_class.new(outsider, group)).to forbid_actions(all_actions) }
  end

  describe 'an admin of a different event' do
    let(:other_admin) do
      create(:user, :member).tap { |u| create(:event_assignment, role: :event_admin, event: create(:event), user: u) }
    end

    it { expect(described_class.new(other_admin, group)).to forbid_actions(all_actions) }
  end
end
