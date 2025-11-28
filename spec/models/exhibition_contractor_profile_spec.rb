require 'rails_helper'

RSpec.describe ExhibitionContractorProfile, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:event_exhibition_contractors).dependent(:destroy) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:company_name) }
    it { is_expected.to validate_presence_of(:contact_person) }
    it { is_expected.to validate_presence_of(:contact_email) }
    it { is_expected.to validate_presence_of(:contact_phone) }
    it { is_expected.to allow_value("test@example.com").for(:contact_email) }
    it { is_expected.to_not allow_value("invalid-email").for(:contact_email) }
  end
end