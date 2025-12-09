require 'rails_helper'

RSpec.describe ItemCategory, type: :model do
  describe 'Validations' do
    subject { create(:item_category) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to allow_value(true).for(:active) }
    it { is_expected.to allow_value(false).for(:active) }
    it { is_expected.to_not allow_value(nil).for(:active) }
  end
end