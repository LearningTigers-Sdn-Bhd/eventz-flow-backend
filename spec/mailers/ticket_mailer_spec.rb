require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  describe '#confirmation_email' do
    let(:event) { create(:event, title: 'Test Event') }
    let(:ticket_type) { create(:ticket_type, event: event, name: 'General Admission') }
    let(:ticket) do
      create(:ticket,
             event: event,
             ticket_type: ticket_type,
             attendee_name: 'John Doe',
             attendee_email: 'john@example.com')
    end

    let(:mail) { described_class.confirmation_email(ticket) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Your ticket for Test Event')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body with attendee name' do
      expect(mail.body.encoded).to include('John Doe')
    end

    it 'renders the body with event title' do
      expect(mail.body.encoded).to include('Test Event')
    end

    it 'renders the body with ticket type' do
      expect(mail.body.encoded).to include('General Admission')
    end

    it 'attaches the QR code' do
      expect(mail.attachments.count).to eq(1)
      expect(mail.attachments.first.filename).to eq('qr_code.png')
    end

    it 'adds receipt bcc for paid tickets' do
      paid_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: ticket_type,
        attendee_name: 'Paid Attendee',
        attendee_email: 'paid@example.com'
      )

      paid_mail = described_class.confirmation_email(paid_ticket)

      expect(paid_mail.bcc).to include('eventpayment@eventzflow.com')
    end

    it 'adds organizer payment receipt bcc from event' do
      event.create_event_email_setting!(payment_receipt_email: 'organizer@example.com')

      paid_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: ticket_type,
        attendee_name: 'Paid Attendee',
        attendee_email: 'paid@example.com'
      )

      paid_mail = described_class.confirmation_email(paid_ticket)
      expect(paid_mail.bcc).to include('organizer@example.com')
    end

    it 'includes payment receipt details for paid tickets' do
      paid_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: ticket_type,
        attendee_name: 'Paid Attendee',
        attendee_email: 'paid@example.com'
      )
      create(
        :ticket_payment,
        :paid,
        :online,
        ticket: paid_ticket,
        amount: 120.0,
        gateway_payment_id: 'pay_receipt_123',
        gateway_response: { order_id: 'order_receipt_123' },
        paid_at: Time.zone.parse('2026-02-28 10:15:00 +08:00')
      )

      paid_mail = described_class.confirmation_email(paid_ticket)

      expect(paid_mail.body.encoded).to include('Payment Receipt')
      expect(paid_mail.body.encoded).to include('Receipt No')
      expect(paid_mail.body.encoded).to include(paid_ticket.public_id)
      expect(paid_mail.body.encoded).to include('Amount Paid')
      expect(paid_mail.body.encoded).to include('MYR 120.00')
      expect(paid_mail.body.encoded).to include('pay_receipt_123')
      expect(paid_mail.body.encoded).to include('order_receipt_123')
    end

    it 'styles payment receipt labels with distinct header color' do
      paid_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: ticket_type,
        attendee_name: 'Paid Attendee',
        attendee_email: 'paid@example.com'
      )

      paid_mail = described_class.confirmation_email(paid_ticket)

      expect(paid_mail.body.encoded).to include('color: #000000;')
    end

    it 'does not show payment receipt section when amount paid is zero' do
      free_ticket_type = create(:ticket_type, event: event, name: 'Visitor', price: 0)
      free_paid_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: free_ticket_type,
        attendee_name: 'Free Attendee',
        attendee_email: 'free@example.com',
        status: :purchased
      )

      free_mail = described_class.confirmation_email(free_paid_ticket)

      expect(free_mail.body.encoded).not_to include('PAYMENT RECEIPT')
      expect(free_mail.body.encoded).not_to include('Payment Receipt')
      expect(free_mail.bcc.to_a).not_to include('eventpayment@eventzflow.com')
    end
  end
end
