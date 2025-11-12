# spec/models/visitor_spec.rb
require 'rails_helper'

RSpec.describe Visitor, type: :model do
  # --- Setup ---
  let(:event) { create(:event) }
  let(:valid_attributes) do
    {
      event: event,
      full_name: 'John Visitor',
      gender: 'male',
      age: 30,
      phone: '+1234567890',
      email: 'visitor@example.com'
    }
  end

  let(:valid_visitor) { build(:visitor, event: event) }

  # --- Associations ---
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:visitor_vendor_stamps).dependent(:destroy) }
  end

  # --- Validations ---
  describe 'Validations' do
    subject { valid_visitor }

    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:full_name) }
  end

  # --- Optional Fields ---
  describe 'Optional Fields' do
    it 'allows all fields to be nullable except event_id and full_name' do
      visitor = Visitor.new(event: event, full_name: 'John Visitor')
      expect(visitor).to be_valid
    end

    it 'allows partial information' do
      visitor = Visitor.new(event: event, full_name: 'John')
      expect(visitor).to be_valid
    end
  end

  # --- Public ID ---
  describe 'Public ID' do
    it 'sets public_id automatically on create' do
      visitor = Visitor.create!(event: event, full_name: 'Test Visitor')
      expect(visitor.public_id).to be_present
      expect(visitor.public_id).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
    end
  end
end
