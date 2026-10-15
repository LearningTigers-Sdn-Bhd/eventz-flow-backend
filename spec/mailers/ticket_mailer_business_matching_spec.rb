require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  describe '#business_matching_email' do
    let(:event) { create(:event, title: 'Test Event', use_business_matching: true) }
    let(:ticket_type) { create(:ticket_type, event: event) }
    let(:ticket) do
      create(:ticket,
             event: event,
             ticket_type: ticket_type,
             attendee_name: 'John Doe',
             attendee_email: 'john@example.com')
    end

    let(:mail) { described_class.business_matching_email(ticket) }

    it 'renders the headers' do
      expect(mail.to).to eq(['john@example.com'])
      expect(mail.subject).to include('Test Event')
    end

    it 'greets the attendee by name' do
      expect(mail.body.encoded).to include('John Doe')
    end

    it 'links to the event book-meeting page by numeric event id' do
      expect(mail.html_part.body.decoded).to include("/event/#{event.id}/book-meeting")
    end
  end
end
