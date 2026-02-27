require 'rails_helper'

RSpec.describe ExhibitorBoothPrice, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:exhibitor_zone).optional }
    it { should have_many(:exhibitor_kits) }
  end

  describe 'validations' do
    subject(:booth_price) { build(:exhibitor_booth_price) }

    it { should validate_presence_of(:booth_type) }
    it { should validate_presence_of(:label) }
    it { should validate_presence_of(:price) }

    it 'validates uniqueness of label scoped to event, booth_type, and exhibitor_zone_id' do
      event = create(:event)
      zone = create(:exhibitor_zone, event: event, zone: 'zone_d')
      create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', exhibitor_zone: zone, label: 'Malaysian')

      duplicate = build(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', exhibitor_zone: zone,
                                                label: 'Malaysian')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:label]).to include('has already been taken')
    end

    it 'allows same label for different zones' do
      event = create(:event)
      zone_d = create(:exhibitor_zone, event: event, zone: 'zone_d')
      zone_c = create(:exhibitor_zone, event: event, zone: 'zone_c')
      create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', exhibitor_zone: zone_d,
                                     label: 'Malaysian')

      same_label_other_zone = build(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme',
                                                            exhibitor_zone: zone_c, label: 'Malaysian')

      expect(same_label_other_zone).to be_valid
    end

    it 'allows null exhibitor_zone' do
      booth_price.exhibitor_zone = nil

      expect(booth_price).to be_valid
    end
  end
end
