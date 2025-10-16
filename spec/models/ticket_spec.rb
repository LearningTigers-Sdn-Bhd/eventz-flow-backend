# spec/models/ticket_spec.rb
require 'rails_helper'

RSpec.describe Ticket, type: :model do
  # Assuming you have factories for these models
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:user) { create(:user) }

  # Factory for a valid Ticket instance
  let(:valid_attributes) do
    {
      event: event,
      ticket_type: ticket_type,
      attendee_name: 'Test Attendee',
      attendee_email: 'test@example.com',
      status: :purchased
      # public_id is set automatically by before_validation
    }
  end

  # --- ASSOCIATIONS ---
  describe 'Associations' do
    it { should belong_to(:event) }
    it { should belong_to(:ticket_type) }
    it { should belong_to(:user).optional }
    it { should belong_to(:order).optional }
  end

  # --- VALIDATIONS ---
  describe 'Validations' do
    # Presence checks
    it { should validate_presence_of(:attendee_name) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:event_id) } # Explicit check
    it { should validate_presence_of(:ticket_type_id) } # Explicit check

    # Email format check
    it { should allow_value('valid@email.com').for(:attendee_email) }
    it { should_not allow_value('invalid-email').for(:attendee_email) }

    # Public ID validation check (only enforced on update in the refactored model)
    describe 'public_id presence' do
      it 'is set automatically on creation' do
        ticket = Ticket.create!(valid_attributes)
        expect(ticket.public_id).to be_present
      end

      it 'validates presence on update' do
        ticket = create(:ticket, valid_attributes)
        ticket.public_id = nil
        expect(ticket.valid?(:update)).to be false
        expect(ticket.errors[:public_id]).to include("can't be blank")
      end
    end
  end

  # --- ENUMS ---
  describe 'Enums' do
    it { should define_enum_for(:status).with_values([:purchased, :scanned, :refunded, :canceled]) }
  end

  # --- SCOPES ---
  describe 'Scopes' do
    before do
      create(:ticket, event: event, status: :purchased, checked_in: false)
      create(:ticket, event: event, status: :scanned, checked_in: true)
      create(:ticket, event: event, status: :refunded, checked_in: true)
      create(:ticket, event: event, status: :canceled, checked_in: false)
    end

    it '.checked_in returns only scanned and refunded tickets' do
      expect(Ticket.checked_in.count).to eq(2)
      expect(Ticket.checked_in.pluck(:status)).to match_array(['scanned', 'refunded'])
    end

    it '.active returns only purchased and scanned tickets' do
      expect(Ticket.active.count).to eq(2)
      expect(Ticket.active.pluck(:status)).to match_array(['purchased', 'scanned'])
    end
  end

  # --- CALLBACKS ---
  describe 'Callbacks' do
    it 'sets a public_id (UUID) before validation on create' do
      ticket = Ticket.new(valid_attributes.except(:public_id))
      ticket.valid?
      expect(ticket.public_id).to be_present
      expect(ticket.public_id).to be_a(String)
      expect(ticket.public_id.length).to be > 10 # Basic UUID check
    end
  end
end