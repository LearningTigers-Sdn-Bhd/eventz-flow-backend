require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  describe '#voucher_showcase_email' do
    let(:event) { create(:event, title: 'Test Event', slug: 'test-event') }
    let(:ticket_type) { create(:ticket_type, event: event) }
    let(:ticket) do
      create(:ticket,
             event: event,
             ticket_type: ticket_type,
             attendee_name: 'John Doe',
             attendee_email: 'john@example.com')
    end
    let(:vendor) { create(:user, full_name: 'Acme Snacks') }

    let(:mail) { described_class.voucher_showcase_email(ticket) }

    it 'renders the headers' do
      expect(mail.to).to eq(['john@example.com'])
      expect(mail.subject).to include('Test Event')
    end

    it 'greets the attendee by name' do
      expect(mail.body.encoded).to include('John Doe')
    end

    it 'lists active vouchers with their vendor' do
      create(:voucher, event: event, vendor: vendor, title: '20% Off Coffee')

      expect(mail.body.encoded).to include('20% Off Coffee')
      expect(mail.body.encoded).to include('Acme Snacks')
    end

    it 'excludes inactive vouchers' do
      create(:voucher, event: event, vendor: vendor, title: 'Retired Deal', status: :inactive)

      expect(mail.body.encoded).not_to include('Retired Deal')
    end

    it 'links to the event voucher showcase page' do
      expect(mail.html_part.body.decoded).to include('/event/test-event/voucher-showcase')
    end

    it 'explains redemption requires scanning both the voucher QR and the ticket QR at the booth' do
      body = mail.html_part.body.decoded
      expect(body).to include("scan the voucher's QR code")
      expect(body).to include('your ticket QR code')
    end
  end
end
