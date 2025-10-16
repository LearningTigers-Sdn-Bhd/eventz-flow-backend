require 'rails_helper'

RSpec.describe EventTeamMember, type: :model do
  # Test subject - create a valid event_team_member instance
  subject { build(:event_team_member) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:event) }
  end

  describe 'Database Columns' do
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:event_id).of_type(:integer) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
  end

  describe 'Database Indexes' do
    it { is_expected.to have_db_index(:user_id) }
    it { is_expected.to have_db_index(:event_id) }
  end

  describe 'Factory' do
    it 'has a valid factory' do
      expect(build(:event_team_member)).to be_valid
    end

    it 'creates a valid event_team_member with associations' do
      event_team_member = create(:event_team_member)
      expect(event_team_member.user).to be_present
      expect(event_team_member.event).to be_present
    end
  end

  describe 'Relationships' do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:event_team_member) { create(:event_team_member, user: user, event: event) }

    it 'links a user to an event' do
      expect(user.event_team_members).to include(event_team_member)
      expect(event.event_team_members).to include(event_team_member)
    end

    it 'allows a user to be a team member of multiple events' do
      event2 = create(:event)
      event_team_member2 = create(:event_team_member, user: user, event: event2)
      
      expect(user.event_team_members.count).to eq(2)
      expect(user.staffed_events).to include(event, event2)
    end

    it 'allows an event to have multiple team members' do
      user2 = create(:user)
      event_team_member2 = create(:event_team_member, user: user2, event: event)
      
      expect(event.event_team_members.count).to eq(2)
      expect(event.team_members).to include(user, user2)
    end
  end

  describe 'Dependent Destroy' do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:event_team_member) { create(:event_team_member, user: user, event: event) }

    it 'is destroyed when the user is destroyed' do
      expect { user.destroy }.to change { EventTeamMember.count }.by(-1)
    end

    it 'is destroyed when the event is destroyed' do
      expect { event.destroy }.to change { EventTeamMember.count }.by(-1)
    end
  end

  describe 'Creation and Persistence' do
    it 'can be created with valid attributes' do
      user = create(:user)
      event = create(:event)
      
      event_team_member = EventTeamMember.new(user: user, event: event)
      expect(event_team_member.save).to be true
      expect(event_team_member.persisted?).to be true
    end

    it 'sets timestamps on creation' do
      event_team_member = create(:event_team_member)
      expect(event_team_member.created_at).to be_present
      expect(event_team_member.updated_at).to be_present
    end
  end
end
