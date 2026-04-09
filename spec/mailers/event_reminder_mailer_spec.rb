require 'rails_helper'

RSpec.describe EventReminderMailer, type: :mailer do
  describe '#pending_payment_reminder' do
    let(:event) { create(:event, title: 'Future of Energy Summit 2026') }
    let(:ticket) { create(:ticket, :pending_payment, event: event, attendee_email: 'pending@example.com') }

    let(:mail) { described_class.pending_payment_reminder(ticket, event) }

    it 'renders the recipient and payment completion subject' do
      expect(mail.to).to eq(['pending@example.com'])
      expect(mail.subject).to eq('Complete your payment for Future of Energy Summit 2026')
    end

    it 'renders payment completion content for the event' do
      expect(mail.body.encoded).to include('pending@example.com')
      expect(mail.body.encoded).to include('Future of Energy Summit 2026')
      expect(mail.body.encoded).to include('Complete your payment for Future of Energy Summit 2026')
    end
  end
end
