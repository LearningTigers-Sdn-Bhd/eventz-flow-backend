require 'rails_helper'

RSpec.describe EventLocationMember, type: :model do
  # --- Setup ---
  let(:event) { create(:event) }
  let(:event_location) { create(:event_location, event: event) }
  let(:user) { create(:member_user) }

  # =========================================================================
  # ASSOCIATIONS
  # =========================================================================
  
  describe 'associations' do
    it { should belong_to(:event_location) }
    it { should belong_to(:member).class_name('User') }
  end

  # =========================================================================
  # VALIDATIONS
  # =========================================================================
  
  describe 'validations' do
    context 'uniqueness validation' do
      it 'validates uniqueness of member_id scoped to event_location_id' do
        # Create first assignment
        create(:event_location_member, event_location: event_location, member: user)
        
        # Try to create duplicate
        duplicate_assignment = build(:event_location_member, event_location: event_location, member: user)
        
        expect(duplicate_assignment).not_to be_valid
        expect(duplicate_assignment.errors[:member_id]).to be_present
      end

      it 'allows same user to be assigned to different locations' do
        location1 = create(:event_location, event: event, name: 'Location 1')
        location2 = create(:event_location, event: event, name: 'Location 2')
        
        create(:event_location_member, event_location: location1, member: user)
        assignment2 = build(:event_location_member, event_location: location2, member: user)
        
        expect(assignment2).to be_valid
      end

      it 'allows different users to be assigned to the same location' do
        user1 = create(:member_user)
        user2 = create(:member_user)
        
        create(:event_location_member, event_location: event_location, member: user1)
        assignment2 = build(:event_location_member, event_location: event_location, member: user2)
        
        expect(assignment2).to be_valid
      end
    end
  end

  # =========================================================================
  # INSTANCE METHODS / BEHAVIOR
  # =========================================================================
  
  describe 'instance behavior' do
    it 'creates a valid event location member assignment' do
      assignment = create(:event_location_member, event_location: event_location, member: user)
      
      expect(assignment).to be_persisted
      expect(assignment.event_location).to eq(event_location)
      expect(assignment.member).to eq(user)
    end

    it 'allows accessing the event location from the member' do
      assignment = create(:event_location_member, event_location: event_location, member: user)
      
      expect(assignment.member.class).to eq(User)
      expect(assignment.event_location.event).to eq(event)
    end
  end
end

