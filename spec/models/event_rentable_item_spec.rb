require 'rails_helper'

RSpec.describe EventRentableItem, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:rentable_item) }
  end
end
