require 'rails_helper'

RSpec.describe TicketApplicationMailer, type: :mailer do
  let(:event) { create(:event, title: 'Sabah Impact Summit') }
  let(:registration_form) { create(:registration_form, event: event, name: 'Interested Delegate', slug: 'interested-delegate') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate Pass') }
  let(:ticket) do
    create(:ticket, :pending_payment, event: event, ticket_type: ticket_type,
                                      attendee_name: 'Aina Rahman', attendee_email: 'aina@example.com')
  end
  let(:application) { create(:ticket_application, ticket: ticket, registration_form: registration_form) }

  before do
    create(:registration_form_rsvp_setting, registration_form: registration_form, enabled: true, rsvp_required: true,
                                             review_sla_hours: 48, notify_by_date: Time.zone.parse('2026-05-15 18:00:00'))
  end

  describe '#acknowledgement' do
    let(:mail) { described_class.acknowledgement(application) }

    it 'acknowledges receipt and review timeline' do
      expect(mail.to).to eq(['aina@example.com'])
      expect(mail.subject).to eq('Application received for Sabah Impact Summit')
      expect(mail.body.encoded).to include('Aina Rahman')
      expect(mail.body.encoded).to include('Within 48 hours')
      expect(mail.body.encoded).to include('May 15, 2026')
    end
  end

  describe '#rsvp_invitation' do
    let(:mail) { described_class.rsvp_invitation(application, 'raw-token-123') }

    it 'includes the RSVP link and approval copy' do
      expect(mail.to).to eq(['aina@example.com'])
      expect(mail.subject).to eq('RSVP required for Sabah Impact Summit')
      expect(mail.body.encoded).to include('approved')
      expect(mail.body.encoded).to include('raw-token-123')
    end
  end

  describe '#rejection' do
    let(:mail) { described_class.rejection(application) }

    it 'uses polite limited-seats wording' do
      expect(mail.to).to eq(['aina@example.com'])
      expect(mail.subject).to eq('Application update for Sabah Impact Summit')
      expect(mail.body.encoded).to include('unable to accept your delegate application')
      expect(mail.body.encoded).to include('limited capacity')
    end
  end
end
