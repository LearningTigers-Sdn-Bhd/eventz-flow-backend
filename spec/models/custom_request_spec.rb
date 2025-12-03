require 'rails_helper'

RSpec.describe CustomRequest, type: :model do
  describe 'Validations' do
    subject { create(:custom_request) }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_numericality_of(:resolved_price).is_greater_than_or_equal_to(0).allow_nil }

    it 'is valid with a defined status' do
      %i[pending approved rejected].each do |status|
        custom_request = build(:custom_request, status: status)
        expect(custom_request).to be_valid
      end
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:exhibitor_kit) }
  end
end
