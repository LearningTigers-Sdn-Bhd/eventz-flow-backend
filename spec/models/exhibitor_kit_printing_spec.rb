require 'rails_helper'

RSpec.describe ExhibitorKitPrinting, type: :model do
  describe 'Validations' do
    # Set up a valid ExhibitorKitPrinting with all required associations
    let(:user) { create(:user, :exhibitor) }
    let(:event) { create(:event) }
    let(:event_vendor) { create(:exhibitor, event: event, vendor: user) } # Create Exhibitor EventVendor
    let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: event_vendor) } # Create ExhibitorKit
    let(:printing_service) { create(:printing_service, status: :active) }
    let!(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) } # Link printing_service to event

    subject { create(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: printing_service) }

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:agreed_price) }
    it { is_expected.to validate_numericality_of(:agreed_price).is_greater_than_or_equal_to(0) }

    it "validates that printing service must be active and linked to the exhibitor kit's event" do
      invalid_printing_service = create(:printing_service, status: :inactive)
      exhibitor_kit_printing = build(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: invalid_printing_service)
      expect(exhibitor_kit_printing).not_to be_valid
      expect(exhibitor_kit_printing.errors[:printing_service]).to include("must be active to be added to the kit")
    end

    it "validates that printing service must be linked to the exhibitor kit's event" do
      unlinked_printing_service = create(:printing_service) # Not linked to 'event'
      exhibitor_kit_printing = build(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: unlinked_printing_service)
      expect(exhibitor_kit_printing).not_to be_valid
      expect(exhibitor_kit_printing.errors[:printing_service]).to include("must be linked to the exhibitor kit's event")
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:exhibitor_kit) }
    it { is_expected.to belong_to(:printing_service) }
  end
end