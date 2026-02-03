require 'rails_helper'

RSpec.describe Ticket, type: :model do
  # --- Setup ---
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:user) { create(:user) }

  let(:valid_attributes) do
    {
      event: event,
      ticket_type: ticket_type,
      user: user,
      attendee_name: 'Test Attendee',
      attendee_email: 'test@example.com',
      status: :purchased
    }
  end

  let(:valid_ticket) { build(:ticket, user: user, event: event, ticket_type: ticket_type) }

  # --- ASSOCIATIONS ---
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:ticket_type) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:check_ins).class_name('TicketCheckIn').dependent(:destroy) }
  end

  # --- VALIDATIONS ---
  describe 'Validations' do
    subject { valid_ticket }

    it { is_expected.to validate_presence_of(:attendee_name) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:payment_status) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:ticket_type_id) }

    it { is_expected.to allow_value('valid@email.com').for(:attendee_email) }
    it { is_expected.not_to allow_value('invalid-email').for(:attendee_email) }

    it { is_expected.to allow_value('+1234567890').for(:attendee_phone) }
    it { is_expected.to allow_value('123-456-7890').for(:attendee_phone) }
    it { is_expected.to allow_value('(123) 456-7890').for(:attendee_phone) }
    it { is_expected.to allow_value('').for(:attendee_phone) }
    it { is_expected.to allow_value(nil).for(:attendee_phone) }
    it { is_expected.not_to allow_value('invalid@phone').for(:attendee_phone) }

    describe 'public_id presence' do
      it 'is set automatically on creation' do
        ticket = Ticket.create!(valid_attributes)
        expect(ticket.public_id).to be_present
      end

      it 'validates presence on update' do
        ticket = create(:ticket, user: user, event: event, ticket_type: ticket_type)
        ticket.public_id = nil
        expect(ticket.valid?(:update)).to be false
        expect(ticket.errors[:public_id]).to include("can't be blank")
      end
    end
  end

  # --- ENUMS ---
  describe 'Enums' do
    it { is_expected.to define_enum_for(:status).with_values(purchased: 0, scanned: 1, refunded: 2, canceled: 3) }
    it { is_expected.to define_enum_for(:payment_status).with_values(pending: 0, paid: 1, failed: 2, refunded_payment: 3) }
  end

  # --- SCOPES ---
  describe 'Scopes' do
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
      expect(ticket.public_id).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
    end
  end

  # --- CHECK-IN HELPER METHODS ---
  describe 'Check-in helper methods' do
    let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type) }

    describe '#checked_in_on?' do
      it 'returns false when no check-ins exist' do
        expect(ticket.checked_in_on?(Date.current)).to be false
      end

      it 'returns true when check-in exists for the date' do
        create(:ticket_check_in, ticket: ticket, check_in_at: Time.current)
        expect(ticket.checked_in_on?(Date.current)).to be true
      end

      it 'returns false for a different date' do
        create(:ticket_check_in, ticket: ticket, check_in_at: 1.day.ago)
        expect(ticket.checked_in_on?(Date.current)).to be false
      end
    end

    describe '#checked_in_today?' do
      it 'returns false when no check-ins exist' do
        expect(ticket.checked_in_today?).to be false
      end

      it 'returns true when check-in exists for today' do
        create(:ticket_check_in, ticket: ticket, check_in_at: Time.current)
        expect(ticket.checked_in_today?).to be true
      end
    end

    describe '#check_in_for' do
      it 'returns nil when no check-in exists for the date' do
        expect(ticket.check_in_for(Date.current)).to be_nil
      end

      it 'returns the check-in record for the date' do
        check_in = create(:ticket_check_in, ticket: ticket, check_in_at: Time.current)
        expect(ticket.check_in_for(Date.current)).to eq(check_in)
      end
    end
  end
end
