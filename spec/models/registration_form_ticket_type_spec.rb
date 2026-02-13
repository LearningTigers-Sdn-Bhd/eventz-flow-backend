require 'rails_helper'

RSpec.describe RegistrationFormTicketType, type: :model do
  describe 'associations' do
    it { should belong_to(:registration_form) }
    it { should belong_to(:ticket_type) }
  end

  describe 'validations' do
    subject(:mapping) { build(:registration_form_ticket_type) }

    it { should define_enum_for(:registration_mode).with_values(single: 0, group: 1).with_prefix(:registration_mode) }
    it { should validate_numericality_of(:min_attendees).is_greater_than_or_equal_to(1) }

    it 'is invalid when max_attendees is less than min_attendees' do
      mapping.min_attendees = 3
      mapping.max_attendees = 2

      expect(mapping).not_to be_valid
      expect(mapping.errors[:max_attendees]).to include('must be greater than or equal to min_attendees')
    end
  end
end
