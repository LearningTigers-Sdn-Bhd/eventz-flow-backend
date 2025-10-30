require 'rails_helper'

RSpec.describe EventLocation, type: :model do
  # --- Setup ---
  let(:event) { create(:event) }
  let(:event_location) { build(:event_location, event: event) }

  # =========================================================================
  # ASSOCIATIONS
  # =========================================================================

  describe 'associations' do
    it { should belong_to(:event).inverse_of(:event_locations) }
    it { should have_many(:event_location_members).dependent(:destroy) }
    it { should have_many(:members).through(:event_location_members) }
  end

  # =========================================================================
  # VALIDATIONS
  # =========================================================================

  describe 'validations' do
    subject { event_location }

    it { should validate_presence_of(:name) }

    it { should validate_numericality_of(:scan_limit)
           .only_integer
           .is_greater_than_or_equal_to(0) }

    it 'allows scan_limit to be nil/negative when is_unlimited is true' do
      unlimited = build(:event_location, event: event, is_unlimited: true, scan_limit: nil)
      expect(unlimited).to be_valid

      unlimited_negative = build(:event_location, event: event, is_unlimited: true, scan_limit: -1)
      expect(unlimited_negative).to be_valid
    end

    context 'uniqueness validation' do
      it 'validates uniqueness of name scoped to event_id' do
        create(:event_location, event: event, name: 'Main Hall')
        duplicate_location = build(:event_location, event: event, name: 'Main Hall')

        expect(duplicate_location).not_to be_valid
        expect(duplicate_location.errors[:name]).to include('already exists for this event')
      end

      it 'allows same name for different events' do
        another_event = create(:event)
        create(:event_location, event: event, name: 'Main Hall')
        duplicate_name_different_event = build(:event_location, event: another_event, name: 'Main Hall')

        expect(duplicate_name_different_event).to be_valid
      end
    end
  end

  # =========================================================================
  # SCOPES
  # =========================================================================

  describe 'scopes' do
    describe '.active' do
      let!(:active_location_1) { create(:event_location, event: event, scan_limit: 100) }
      let!(:active_location_2) { create(:event_location, event: event, scan_limit: 50) }
      let!(:inactive_location) { create(:event_location, event: event, scan_limit: 0) }
      let!(:unlimited_location) { create(:event_location, event: event, is_unlimited: true, scan_limit: 0) }

      it 'returns locations with scan_limit > 0 or is_unlimited' do
        expect(EventLocation.active).to include(active_location_1, active_location_2, unlimited_location)
        expect(EventLocation.active).not_to include(inactive_location)
      end
    end
  end

  # =========================================================================
  # INSTANCE METHODS / BEHAVIOR
  # =========================================================================

  describe 'instance behavior' do
    it 'creates a valid event location' do
      event_location = create(:event_location, event: event, name: 'VIP Lounge', scan_limit: 25)

      expect(event_location).to be_persisted
      expect(event_location.name).to eq('VIP Lounge')
      expect(event_location.scan_limit).to eq(25)
    end

    it 'can have members assigned' do
      user1 = create(:member_user)
      user2 = create(:member_user)
      location = create(:event_location, event: event)

      location.event_location_members.create(member: user1)
      location.event_location_members.create(member: user2)

      expect(location.members.count).to eq(2)
      expect(location.members).to include(user1, user2)
    end

    it 'destroys associated event_location_members when destroyed' do
      user = create(:member_user)
      location = create(:event_location, event: event)
      location.event_location_members.create(member: user)

      expect { location.destroy }.to change { EventLocationMember.count }.by(-1)
    end
  end
end
