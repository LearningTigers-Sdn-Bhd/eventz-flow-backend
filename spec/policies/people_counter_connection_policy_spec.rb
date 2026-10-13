require 'rails_helper'

RSpec.describe PeopleCounterConnectionPolicy, type: :policy do
  let(:event) { create(:event, published: false) }
  let(:connection) { PeopleCounterConnection.new(event: event) }

  let(:org_owner) { create(:user, :org_owner) }
  let(:event_admin) do
    create(:user, :organizer).tap { |u| create(:event_assignment, role: :event_admin, event: event, user: u) }
  end
  let(:outsider) { create(:user, :member) }

  it { expect(described_class.new(org_owner, connection)).to permit_actions(%i[show update destroy test]) }
  it { expect(described_class.new(event_admin, connection)).to forbid_actions(%i[show update destroy test]) }
  it { expect(described_class.new(outsider, connection)).to forbid_actions(%i[show update destroy test]) }
  it { expect(described_class.new(nil, connection)).to forbid_actions(%i[show update destroy test]) }
end
