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
    it { is_expected.to have_many(:event_leads).dependent(:destroy) }
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

    it 'allows dynamic role' do
      visitor = Visitor.new(event: event, full_name: 'John', role: 'Speaker')
      expect(visitor).to be_valid
      expect(visitor.role).to eq('Speaker')
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

  # --- Custom Fields ---
  describe 'custom_fields_data' do
    it 'can accept and save custom_fields_data' do
      visitor = build(:visitor, event: event, custom_fields_data: { "t-shirt" => "L", "meal" => "vegan" })
      expect(visitor.custom_fields_data).to eq({ "t-shirt" => "L", "meal" => "vegan" })
      
      visitor.save!
      visitor.reload
      
      expect(visitor.custom_fields_data).to eq({ "t-shirt" => "L", "meal" => "vegan" })
    end
  end

  # --- Scopes ---
  describe 'Scopes' do
    let!(:checked_in_visitors) { create_list(:visitor, 2, event: event, checked_in: true) }
    let!(:not_checked_in_visitors) { create_list(:visitor, 3, event: event, checked_in: false) }

    describe '.checked_in' do
      it 'returns only visitors who have checked in' do
        expect(Visitor.checked_in.count).to eq(2)
        expect(Visitor.checked_in).to match_array(checked_in_visitors)
      end
    end

    describe '.unscanned' do
      it 'returns only visitors who have not checked in' do
        expect(Visitor.unscanned.count).to eq(3)
        expect(Visitor.unscanned).to match_array(not_checked_in_visitors)
      end
    end
  end

  describe '#send_webhook_notification' do
    let(:event) { create(:event, webhook_url: 'https://example.com/w1, https://example.com/w2') }
    let(:visitor) { create(:visitor, event: event) }

    before do
      allow(visitor).to receive(:determine_event_type).and_return('visitor.created')
    end

    it 'enqueues a WebhookSenderJob for each URL' do
      expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w1', any_args)
      expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w2', any_args)

      visitor.send(:send_webhook_notification)
    end

    it 'skips if skip_webhooks is true' do
      visitor.skip_webhooks = true
      expect(WebhookSenderJob).not_to receive(:perform_later)
      visitor.send(:send_webhook_notification)
    end
  end
end
