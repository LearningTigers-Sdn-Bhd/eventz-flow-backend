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
    it { is_expected.to have_many(:event_reminder_logs).dependent(:destroy) }
    # To test this, ensure the `tickets` table has an `order_id` column.
    # it { is_expected.to belong_to(:order).optional }
  end

  describe 'dependent cleanup' do
    it 'destroys reminder logs when the ticket is destroyed' do
      ticket = create(:ticket, event: event, ticket_type: ticket_type)
      create(:event_reminder_log, event: event, ticket: ticket, reminder_type: '7_day')

      expect { ticket.destroy! }.to change(EventReminderLog, :count).by(-1)
    end
  end

  # --- VALIDATIONS ---
  describe 'Validations' do
    # Subject defined using FactoryBot for cleaner `should validate_presence_of` checks
    subject { valid_ticket }

    # Presence checks
    it { is_expected.to validate_presence_of(:attendee_name) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:payment_status) }

    # We rely on belongs_to validations for foreign keys in modern Rails,
    # but explicit checks are fine if preferred:
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:ticket_type_id) }

    # Email format check
    it { is_expected.to allow_value('valid@email.com').for(:attendee_email) }
    it { is_expected.not_to allow_value('invalid-email').for(:attendee_email) }

    # Phone format check
    it { is_expected.to allow_value('+1234567890').for(:attendee_phone) }
    it { is_expected.to allow_value('123-456-7890').for(:attendee_phone) }
    it { is_expected.to allow_value('(123) 456-7890').for(:attendee_phone) }
    it { is_expected.to allow_value('').for(:attendee_phone) } # Allow blank
    it { is_expected.to allow_value(nil).for(:attendee_phone) } # Allow nil
    it { is_expected.not_to allow_value('invalid@phone').for(:attendee_phone) }

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
    it {
      is_expected.to define_enum_for(:status).with_values(purchased: 0, scanned: 1, refunded: 2, canceled: 3,
                                                          pending_payment: 4)
    }
    it {
      is_expected.to define_enum_for(:payment_status).with_values(pending: 0, paid: 1, failed: 2, refunded_payment: 3)
    }
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

    it 'does not send confirmation email for free group member while leader payment is pending' do
      free_ticket_type = create(:ticket_type, event: event, price: 0)

      expect do
        create(
          :ticket,
          event: event,
          ticket_type: free_ticket_type,
          attendee_email: 'member@example.com',
          registered_by_email: 'leader@example.com',
          status: :pending_payment,
          payment_status: :pending
        )
      end.not_to have_enqueued_job(EmailDeliveryJob)
    end

    it 'sends confirmation email for free ticket when ticket is already paid' do
      free_ticket_type = create(:ticket_type, event: event, price: 0)

      expect do
        create(
          :ticket,
          event: event,
          ticket_type: free_ticket_type,
          attendee_email: 'free@example.com',
          status: :purchased,
          payment_status: :paid
        )
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    it 'sends confirmation email when free group member becomes paid after leader payment' do
      free_ticket_type = create(:ticket_type, event: event, price: 0)
      member_ticket = create(
        :ticket,
        event: event,
        ticket_type: free_ticket_type,
        attendee_email: 'member-afterpay@example.com',
        registered_by_email: 'leader@example.com',
        status: :pending_payment,
        payment_status: :pending
      )

      expect do
        member_ticket.update!(status: :purchased, payment_status: :paid)
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    it 'does not send confirmation email when a ticket is created on the waiting list' do
      expect do
        create(
          :ticket,
          event: event,
          ticket_type:,
          attendee_email: 'waiting@example.com',
          waiting_list: true,
          status: :pending_payment,
          payment_status: :pending
        )
      end.not_to have_enqueued_job(EmailDeliveryJob)
    end

    it 'sends confirmation email once a waiting-list ticket is accepted' do
      waiting_ticket = create(
        :ticket,
        event: event,
        ticket_type:,
        attendee_email: 'waiting-accepted@example.com',
        waiting_list: true,
        status: :pending_payment,
        payment_status: :pending
      )

      expect do
        waiting_ticket.update!(waiting_list: false, status: :purchased, payment_status: :paid)
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    it 'does not send confirmation email when explicitly suppressed' do
      suppressed_ticket = create(
        :ticket,
        event: event,
        ticket_type:,
        attendee_email: 'suppressed@example.com',
        status: :pending_payment,
        payment_status: :pending
      )
      suppressed_ticket.suppress_confirmation_email = true

      expect do
        suppressed_ticket.update!(status: :purchased, payment_status: :paid)
      end.not_to have_enqueued_job(EmailDeliveryJob)
    end
  end

  describe '#send_webhook_notification' do
    let(:event) { create(:event, webhook_url: 'https://example.com/w1, https://example.com/w2') }
    let(:ticket) { create(:ticket, event: event) }

    before do
      allow(ticket).to receive(:determine_event_type).and_return('ticket.created')
    end

    it 'enqueues a WebhookSenderJob for each URL' do
      expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w1', any_args)
      expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w2', any_args)

      ticket.send_webhook_notification
    end

    it 'skips if skip_webhooks is true' do
      ticket.skip_webhooks = true
      expect(WebhookSenderJob).not_to receive(:perform_later)
      ticket.send_webhook_notification
    end
  end

  describe 'unique custom fields within event' do
    let(:event) { create(:event) }
    let(:ticket_type) { create(:ticket_type, event: event) }

    def build_with(fields, evt: event)
      build(:ticket, event: evt, ticket_type: ticket_type, custom_fields_data: fields)
    end

    def insert_without_validations(fields, allow_multiple:, evt: event)
      Ticket.insert!({
        event_id: evt.id,
        ticket_type_id: ticket_type.id,
        attendee_name: 'Direct Insert',
        attendee_email: 'direct@example.com',
        status: Ticket.statuses[:purchased],
        payment_status: Ticket.payment_statuses[:pending],
        custom_fields_data: fields,
        allow_multiple_tickets_per_email: allow_multiple,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    it 'allows blank values to repeat' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'membership_no' => '' })
      expect(build_with({ 'membership_no' => '' })).to be_valid
    end

    it 'rejects the same membership_no with different case' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'membership_no' => 'A-1234' })
      ticket = build_with({ 'membership_no' => 'a-1234' })

      expect(ticket).not_to be_valid
      expect(ticket.errors[:base].first).to include('already registered')
    end

    it 'rejects a duplicate ic_passport_no' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'ic_passport_no' => 'H12345678' })
      expect(build_with({ 'ic_passport_no' => 'H12345678' })).not_to be_valid
    end

    it 'accepts duplicate ic_passport_no when multiple tickets per email are allowed' do
      event.update!(allow_multiple_tickets_per_email: true)
      create(:ticket, event: event, ticket_type: ticket_type,
                      custom_fields_data: { 'ic_passport_no' => 'H12345678' })

      expect do
        create(:ticket, event: event, ticket_type: ticket_type,
                       custom_fields_data: { 'ic_passport_no' => 'H12345678' })
      end.not_to raise_error
    end

    it 'accepts duplicate membership_no when multiple tickets per email are allowed' do
      event.update!(allow_multiple_tickets_per_email: true)
      create(:ticket, event: event, ticket_type: ticket_type,
                      custom_fields_data: { 'membership_no' => 'M-1234' })

      expect do
        create(:ticket, event: event, ticket_type: ticket_type,
                       custom_fields_data: { 'membership_no' => 'M-1234' })
      end.not_to raise_error
    end

    it 'keeps flag-off uniqueness after a flag-on ticket is created' do
      create(:ticket, event: event, ticket_type: ticket_type,
                      custom_fields_data: { 'ic_passport_no' => 'H12345678' })

      event.update!(allow_multiple_tickets_per_email: true)
      create(:ticket, event: event, ticket_type: ticket_type,
                      custom_fields_data: { 'ic_passport_no' => 'H12345678' })

      event.update!(allow_multiple_tickets_per_email: false)
      later_flag_off_ticket = build_with({ 'ic_passport_no' => 'H12345678' })

      expect(later_flag_off_ticket).not_to be_valid
      expect(later_flag_off_ticket.errors[:base].first).to include('already registered')
    end

    it 'rejects a duplicate direct insert when multiple tickets per email are disabled' do
      insert_without_validations({ 'ic_passport_no' => 'H12345678' }, allow_multiple: false)

      expect do
        insert_without_validations({ 'ic_passport_no' => 'H12345678' }, allow_multiple: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows duplicate direct inserts when multiple tickets per email are enabled' do
      event.update!(allow_multiple_tickets_per_email: true)
      insert_without_validations({ 'ic_passport_no' => 'H12345678' }, allow_multiple: true)

      expect do
        insert_without_validations({ 'ic_passport_no' => 'H12345678' }, allow_multiple: true)
      end.not_to raise_error
    end

    it 'frees the value when the existing ticket is canceled' do
      create(:ticket, event: event, ticket_type: ticket_type, status: :canceled,
                      custom_fields_data: { 'membership_no' => 'A-1234' })
      expect(build_with({ 'membership_no' => 'A-1234' })).to be_valid
    end

    it 'does not collide across events' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'membership_no' => 'A-1234' })
      other_event = create(:event)
      other_type = create(:ticket_type, event: other_event)
      other = build(:ticket, event: other_event, ticket_type: other_type,
                             custom_fields_data: { 'membership_no' => 'A-1234' })

      expect(other).to be_valid
    end
  end

  describe 'allow_multiple_tickets_per_email mirror' do
    let(:event) { create(:event, allow_multiple_tickets_per_email: true) }
    let(:ticket_type) { create(:ticket_type, event: event) }

    it 'mirrors the enabled event flag when a ticket is created' do
      ticket = create(:ticket, event: event, ticket_type: ticket_type)

      expect(ticket.allow_multiple_tickets_per_email).to be true
    end

    it 'mirrors the disabled event flag when a ticket is created' do
      event.update!(allow_multiple_tickets_per_email: false)
      ticket = create(:ticket, event: event, ticket_type: ticket_type)

      expect(ticket.allow_multiple_tickets_per_email).to be false
    end

    it 'does not change an existing ticket until that ticket is saved' do
      event.update!(allow_multiple_tickets_per_email: false)
      ticket = create(:ticket, event: event, ticket_type: ticket_type)

      event.update!(allow_multiple_tickets_per_email: true)
      expect(ticket.reload.allow_multiple_tickets_per_email).to be false

      ticket.update!(attendee_name: 'Updated Attendee')

      expect(ticket.reload.allow_multiple_tickets_per_email).to be true
    end
  end
end
