require 'rails_helper'

RSpec.describe EventRentableItemPriceTier, type: :model do
  describe 'Validations' do
    subject { create(:event_rentable_item_price_tier) }

    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:label) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:event_rentable_item) }
  end
end
