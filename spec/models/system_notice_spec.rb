require 'rails_helper'

RSpec.describe SystemNotice do
  describe '.current' do
    it 'creates the singleton switched off, once' do
      expect { described_class.current }.to change(described_class, :count).by(1)
      expect(described_class.current).to have_attributes(message: '', active: false)
      expect(described_class.count).to eq(1)
    end
  end

  describe 'validations' do
    it 'requires a message when switched on' do
      notice = described_class.new(active: true, message: '')

      expect(notice).not_to be_valid
      expect(notice.errors[:message]).to be_present
    end

    it 'allows an empty message while switched off' do
      expect(described_class.new(active: false, message: '')).to be_valid
    end

    it 'rejects a message longer than 300 characters' do
      expect(described_class.new(active: true, message: 'a' * 301)).not_to be_valid
      expect(described_class.new(active: true, message: 'a' * 300)).to be_valid
    end
  end

  describe '#public_message' do
    it 'is nil while switched off, even with a saved message' do
      expect(described_class.new(active: false, message: 'Update tonight').public_message).to be_nil
    end

    it 'is the message while switched on' do
      expect(described_class.new(active: true, message: 'Update tonight').public_message).to eq('Update tonight')
    end
  end
end
