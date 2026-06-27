require 'rails_helper'

RSpec.describe CertificateMailer, type: :mailer do
  describe '#certificate_email' do
    let(:event) { create(:event, title: 'Future of Energy Summit 2026') }
    let!(:template) { create(:certificate_template, :ready, event: event) }
    let(:ticket) { create(:ticket, event: event, attendee_name: 'Jane Attendee', attendee_email: 'jane@example.com') }

    let(:mail) { described_class.certificate_email(ticket) }

    it 'sends to the attendee email with a clear subject' do
      expect(mail.to).to eq(['jane@example.com'])
      expect(mail.subject).to eq('Your certificate for Future of Energy Summit 2026')
    end

    it 'attaches a PDF certificate' do
      attachment = mail.attachments.find { |a| a.filename == 'certificate.pdf' }
      expect(attachment).to be_present
      expect(attachment.mime_type).to eq('application/pdf')
      expect(attachment.body.raw_source[0, 5]).to eq('%PDF-')
    end

    it 'greets the attendee by name and references the event' do
      expect(mail.body.encoded).to include('Jane Attendee')
      expect(mail.body.encoded).to include('Future of Energy Summit 2026')
    end
  end
end
