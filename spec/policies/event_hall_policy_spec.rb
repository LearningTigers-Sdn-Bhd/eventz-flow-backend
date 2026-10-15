require 'rails_helper'

RSpec.describe EventHallPolicy, type: :policy do
  let(:event) { create(:event, published: false) }
  let(:hall) { create(:event_hall, event: event) }

  let(:org_owner) { create(:user, :org_owner) }
  let(:event_admin) do
    create(:user, :organizer).tap { |u| create(:event_assignment, role: :event_admin, event: event, user: u) }
  end
  let(:outsider) { create(:user, :member) }

  describe 'org owner' do
    it { expect(described_class.new(org_owner, hall)).to permit_actions(%i[index show create update destroy link_counter]) }
  end

  describe 'event admin / organizer: view only' do
    it { expect(described_class.new(event_admin, hall)).to permit_actions(%i[index show]) }
    it { expect(described_class.new(event_admin, hall)).to forbid_actions(%i[create update destroy link_counter]) }
  end

  describe 'user with no access to the event' do
    it { expect(described_class.new(outsider, hall)).to forbid_actions(%i[show create update destroy link_counter]) }
  end

  describe 'a public (published, visible) event' do
    let(:event) { create(:event, published: true, visibility: true, status: :published) }
    let(:team_member) do
      create(:user, :member).tap { |u| create(:event_assignment, role: :event_team_member, event: event, user: u) }
    end

    it 'is still closed to an ordinary member, even though anyone may view the event' do
      expect(EventPolicy.new(outsider, event).show?).to be(true)
      expect(described_class.new(outsider, hall)).to forbid_actions(%i[index show])
    end

    it 'is closed to a guest' do
      expect(described_class.new(nil, hall)).to forbid_actions(%i[index show])
    end

    it "is open to the event's own team member, view only" do
      expect(described_class.new(team_member, hall)).to permit_actions(%i[index show])
      expect(described_class.new(team_member, hall)).to forbid_actions(%i[create update destroy link_counter])
    end
  end

  describe 'guest' do
    it { expect(described_class.new(nil, hall)).to forbid_actions(%i[show create update destroy link_counter]) }
  end

  describe 'Scope' do
    it 'returns every hall to org owners and only staffed events to everyone else' do
      other_hall = create(:event_hall)
      scope = described_class::Scope.new(org_owner, EventHall).resolve
      expect(scope).to include(hall, other_hall)
      expect(described_class::Scope.new(outsider, EventHall).resolve).not_to include(hall)
      expect(described_class::Scope.new(event_admin, EventHall).resolve).to include(hall)
    end

    it 'hides the halls of a public event from an ordinary member' do
      public_event = create(:event, published: true, visibility: true, status: :published)
      public_hall = create(:event_hall, event: public_event)
      expect(described_class::Scope.new(outsider, EventHall).resolve).not_to include(public_hall)
    end
  end
end
