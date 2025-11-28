require 'rails_helper'

RSpec.describe EventExhibitionContractor, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:exhibition_contractor_profile) }
  end

  describe 'Validations' do
    subject { create(:event_exhibition_contractor) } # Create a subject for uniqueness test
    it { is_expected.to validate_uniqueness_of(:event_id) }
  end

end