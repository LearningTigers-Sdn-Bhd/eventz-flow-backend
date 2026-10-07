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

    context 'with a template assigned to a ticket type' do
      let(:committee) { create(:ticket_type, event: event) }
      let!(:committee_template) do
        create(:certificate_template, :ready, event: event, name: 'Jawatankuasa', ticket_type_ids: [committee.id])
      end

      it 'renders the committee ticket from its own template' do
        committee_ticket = create(:ticket, event: event, ticket_type: committee, attendee_email: 'ajk@example.com')
        used = []
        allow(CertificatePdfGenerator).to receive(:new).and_wrap_original do |m, tpl, *args, **kw|
          used << tpl
          m.call(tpl, *args, **kw)
        end

        described_class.certificate_email(committee_ticket).message
        described_class.certificate_email(ticket).message

        expect(used).to eq([committee_template, template])
      end
    end
  end
end
