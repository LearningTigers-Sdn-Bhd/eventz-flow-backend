require 'rails_helper'

RSpec.describe ExhibitorKitItem, type: :model do
  describe 'Validations' do
    # Set up a valid ExhibitorKitItem with all required associations
    let(:user) { create(:user, :exhibitor) }
    let(:event) { create(:event) }
    let(:event_vendor) { create(:exhibitor, event: event, vendor: user) } # Create Exhibitor EventVendor
    let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: event_vendor) } # Create ExhibitorKit
    let(:rentable_item) { create(:rentable_item, status: :active) }
    let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) } # Link rentable_item to event

    subject { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item) }

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:agreed_price) }
    it { is_expected.to validate_numericality_of(:agreed_price).is_greater_than_or_equal_to(0) }

    it "validates that rentable item must be active and linked to the exhibitor kit's event" do
      invalid_rentable_item = create(:rentable_item, status: :inactive)
      exhibitor_kit_item = build(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: invalid_rentable_item)
      expect(exhibitor_kit_item).not_to be_valid
      expect(exhibitor_kit_item.errors[:rentable_item]).to include("must be active to be added to the kit")
    end

    it "validates that rentable item must be linked to the exhibitor kit's event" do
      unlinked_rentable_item = create(:rentable_item) # Not linked to 'event'
      exhibitor_kit_item = build(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: unlinked_rentable_item)
      expect(exhibitor_kit_item).not_to be_valid
      expect(exhibitor_kit_item.errors[:rentable_item]).to include("must be linked to the exhibitor kit's event")
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:exhibitor_kit) }
    it { is_expected.to belong_to(:rentable_item) }
  end
end