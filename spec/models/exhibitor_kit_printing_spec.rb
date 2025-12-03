require 'rails_helper'

RSpec.describe ExhibitorKitPrinting, type: :model do
  describe 'Validations' do
    subject { create(:exhibitor_kit_printing) }

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:agreed_price) }
    it { is_expected.to validate_numericality_of(:agreed_price).is_greater_than_or_equal_to(0) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:exhibitor_kit) }
    it { is_expected.to belong_to(:printing_service) }
  end
end
