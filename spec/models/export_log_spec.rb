require 'rails_helper'

RSpec.describe ExportLog, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
  end

  describe 'validations' do
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:sheet_path) }
    it { should validate_presence_of(:event_id) }
  end

  describe 'inheritance_column' do
    it 'disables STI by overriding inheritance_column' do
      expect(ExportLog.inheritance_column).not_to eq('type')
    end
  end
end
