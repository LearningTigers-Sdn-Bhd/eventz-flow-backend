require 'rails_helper'

RSpec.describe EventPrintingService, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:printing_service) }
  end
end
