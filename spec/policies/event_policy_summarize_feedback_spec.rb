require 'rails_helper'

RSpec.describe EventPolicy, '#summarize_feedback?' do
  let(:event) { create(:event) }

  it 'allows only an org_owner' do
    expect(described_class.new(create(:user, :org_owner), event).summarize_feedback?).to be(true)
    expect(described_class.new(create(:user, :organizer), event).summarize_feedback?).to be(false)
    expect(described_class.new(create(:user, :member), event).summarize_feedback?).to be(false)
  end

  it 'denies an event admin, who can otherwise manage the event' do
    admin = create(:user, :organizer)
    create(:event_assignment, role: :event_admin, event:, user: admin)
    expect(described_class.new(admin, event).update?).to be(true)
    expect(described_class.new(admin, event).summarize_feedback?).to be(false)
  end

  it 'denies a missing user' do
    expect(described_class.new(nil, event).summarize_feedback?).to be(false)
  end
end
