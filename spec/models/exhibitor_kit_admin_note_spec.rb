require 'rails_helper'

RSpec.describe ExhibitorKitAdminNote, type: :model do
  describe 'Validations' do
    subject { create(:exhibitor_kit_admin_note) }

    it { is_expected.to validate_presence_of(:note) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:exhibitor_kit) }
    it { is_expected.to belong_to(:user) }
  end
end
