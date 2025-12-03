require 'rails_helper'

RSpec.describe RentableItem, type: :model do
  describe 'Validations' do
    subject { create(:rentable_item) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:unit_of_measure) }
    it { is_expected.to validate_presence_of(:default_price) }
    it { is_expected.to validate_numericality_of(:default_price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:status) }

    it 'is valid with a defined status' do
      %i[active inactive].each do |status|
        rentable_item = build(:rentable_item, status: status)
        expect(rentable_item).to be_valid
      end
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:item_category) }
    it { is_expected.to belong_to(:user) }
  end
end
