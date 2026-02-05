require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  describe '#confirmation_email' do
    let(:event) { create(:event, title: "Test Event") }
    let(:ticket_type) { create(:ticket_type, event: event, name: "General Admission") }
    let(:ticket) do
      create(:ticket,
        event: event,
        ticket_type: ticket_type,
        attendee_name: "John Doe",
        attendee_email: "john@example.com"
      )
    end

    let(:mail) { described_class.confirmation_email(ticket) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Your ticket for Test Event")
      expect(mail.to).to eq(["john@example.com"])
    end

    it 'renders the body with attendee name' do
      expect(mail.body.encoded).to include("John Doe")
    end

    it 'renders the body with event title' do
      expect(mail.body.encoded).to include("Test Event")
    end

    it 'renders the body with ticket type' do
      expect(mail.body.encoded).to include("General Admission")
    end

    it 'attaches the QR code' do
      expect(mail.attachments.count).to eq(1)
      expect(mail.attachments.first.filename).to eq("qr_code.png")
    end
  end
end
