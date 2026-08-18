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

    it 'uses upgrade-specific copy for borneo combined tickets' do
      borneo_event = create(:event, title: 'Business C-nergy & Growth Conference Cum Borneo Exhibition',
                                    slug: 'borneo-expo')
      combined_ticket_type = create(:ticket_type, event: borneo_event, name: 'Exhibitor & Conference')
      combined_ticket = create(
        :ticket,
        :paid,
        event: borneo_event,
        ticket_type: combined_ticket_type,
        attendee_name: 'Shin',
        attendee_email: 'shin@example.com'
      )

      combined_mail = described_class.confirmation_email(combined_ticket)
      html_body = combined_mail.html_part&.body&.decoded || combined_mail.body.encoded

      expect(html_body).to include('Your existing ticket has been upgraded to <strong>Exhibitor &amp; Conference</strong>')
      expect(html_body).to include('Your same QR code remains valid')
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

    it 'does not show payment receipt section but still bccs when amount paid is zero' do
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
      expect(free_mail.bcc.to_a).to include('eventpayment@eventzflow.com')
    end
  end

  describe '#group_confirmation_email' do
    let(:event) { create(:event, title: 'Group Event') }
    let(:ticket_type) { create(:ticket_type, event: event, name: 'Group Admission') }
    let(:registered_by_email) { 'buyer@example.com' }

    def create_paid_ticket(name:, email:, registered_by: registered_by_email)
      create(
        :ticket,
        :paid,
        event: event,
        ticket_type: ticket_type,
        attendee_name: name,
        attendee_email: email,
        registered_by_email: registered_by,
        status: :purchased
      )
    end

    it 'renders one mail with one inline QR attachment per shared-address ticket' do
      tickets = 8.times.map do |index|
        create_paid_ticket(name: "Attendee #{index + 1}", email: 'shared@example.com')
      end

      mail = described_class.group_confirmation_email(tickets.first)

      expect(mail.to).to eq(['shared@example.com'])
      expect(mail.subject).to eq('Your tickets for Group Event')
      expect(mail.attachments.map(&:filename)).to contain_exactly(
        *8.times.map { |index| "qr_code_#{index}.png" }
      )
      tickets.each do |ticket|
        expect(mail.body.encoded).to include(ticket.attendee_name)
      end
    end

    it 'keeps existing distinct-email group registrations at one mail and one QR each' do
      tickets = 8.times.map do |index|
        create_paid_ticket(name: "Attendee #{index + 1}", email: "attendee#{index + 1}@example.com")
      end

      mails = tickets.map { |ticket| described_class.group_confirmation_email(ticket) }

      expect(mails).to have_attributes(size: 8)
      expect(mails).to all(satisfy { |mail| mail.attachments.size == 1 })
    end

    it 'renders one mail for three shared tickets and one for each distinct address' do
      shared_tickets = 3.times.map do |index|
        create_paid_ticket(name: "Shared Attendee #{index + 1}", email: 'shared@example.com')
      end
      distinct_tickets = 2.times.map do |index|
        create_paid_ticket(name: "Distinct Attendee #{index + 1}", email: "distinct#{index + 1}@example.com")
      end

      representatives = [shared_tickets.first, *distinct_tickets]
      mails = representatives.map { |ticket| described_class.group_confirmation_email(ticket) }

      expect(mails).to have_attributes(size: 3)
      expect(mails.first.attachments.size).to eq(3)
      expect(mails.drop(1)).to all(satisfy { |mail| mail.attachments.size == 1 })
    end

    it 'does not group tickets without a registered-by email' do
      first_ticket = create_paid_ticket(name: 'First Attendee', email: 'shared@example.com', registered_by: nil)
      second_ticket = create_paid_ticket(name: 'Second Attendee', email: 'shared@example.com', registered_by: nil)

      mail = described_class.group_confirmation_email(first_ticket)

      expect(mail.attachments.map(&:filename)).to eq(['qr_code_0.png'])
      expect(mail.body.encoded).to include(first_ticket.attendee_name)
      expect(mail.body.encoded).not_to include(second_ticket.attendee_name)
    end
  end
end
