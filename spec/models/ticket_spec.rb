require 'rails_helper'

RSpec.describe Ticket, type: :model do
  # --- Setup ---
  # Assuming factories for these models exist and are working:
  # :event, :ticket_type, and :user
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:user) { create(:user) }

  # Factory for a valid Ticket instance - MUST INCLUDE user_id
  let(:valid_attributes) do
    {
      event: event,
      ticket_type: ticket_type,
      user: user, # ✅ FIX: Include the user association
      attendee_name: 'Test Attendee',
      attendee_email: 'test@example.com',
      status: :purchased
      # public_id is set automatically by before_validation
    }
  end
  # Helper to easily create a valid ticket using the factory
  let(:valid_ticket) { build(:ticket, user: user, event: event, ticket_type: ticket_type) }


  # --- ASSOCIATIONS ---
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:ticket_type) }
    it { is_expected.to belong_to(:user).optional }
    # To test this, ensure the `tickets` table has an `order_id` column.
    # it { is_expected.to belong_to(:order).optional }
  end

  # --- VALIDATIONS ---
  describe 'Validations' do
    # Subject defined using FactoryBot for cleaner `should validate_presence_of` checks
    subject { valid_ticket }

    # Presence checks
    it { is_expected.to validate_presence_of(:attendee_name) }
    it { is_expected.to validate_presence_of(:status) }
    
    # We rely on belongs_to validations for foreign keys in modern Rails, 
    # but explicit checks are fine if preferred:
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:ticket_type_id) }

    # Email format check
    it { is_expected.to allow_value('valid@email.com').for(:attendee_email) }
    it { is_expected.not_to allow_value('invalid-email').for(:attendee_email) }

    # Public ID validation check (only enforced on update in the refactored model)
    describe 'public_id presence' do
      # Test using the raw attributes to check the model's logic directly
      it 'is set automatically on creation' do
        # Use the attributes hash to create the record
        ticket = Ticket.create!(valid_attributes) 
        expect(ticket.public_id).to be_present
      end

      it 'validates presence on update' do
        # Use the Factory to create a clean, persisted record
        ticket = create(:ticket, user: user, event: event, ticket_type: ticket_type)
        
        ticket.public_id = nil
        # Use `valid?(:update)` to trigger the conditional validation
        expect(ticket.valid?(:update)).to be false
        expect(ticket.errors[:public_id]).to include("can't be blank")
      end
    end
  end

  # --- ENUMS ---
  describe 'Enums' do
    it { is_expected.to define_enum_for(:status).with_values(purchased: 0, scanned: 1, refunded: 2, canceled: 3) }
  end

  # --- SCOPES ---
  describe 'Scopes' do
    # Use let! to create the records once before the scope tests run
    let!(:purchased) { create(:ticket, event: event, status: :purchased, checked_in: false) }
    let!(:scanned) { create(:ticket, event: event, status: :scanned, checked_in: true) }
    let!(:refunded) { create(:ticket, event: event, status: :refunded, checked_in: true) }
    let!(:canceled) { create(:ticket, event: event, status: :canceled, checked_in: false) }

    it '.checked_in returns only scanned and refunded tickets' do
      expect(Ticket.checked_in).to match_array([scanned, refunded])
      expect(Ticket.checked_in.count).to eq(2)
    end

    it '.active returns only purchased and scanned tickets' do
      expect(Ticket.active).to match_array([purchased, scanned])
      expect(Ticket.active.count).to eq(2)
    end
  end

  # --- CALLBACKS ---
  describe 'Callbacks' do
    it 'sets a public_id (UUID) before validation on create' do
      ticket = Ticket.new(valid_attributes.except(:public_id))
      ticket.valid?
      
      expect(ticket.public_id).to be_present
      expect(ticket.public_id).to be_a(String)
      # Using a UUID regex is more robust than length check
      expect(ticket.public_id).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
    end
  end
end