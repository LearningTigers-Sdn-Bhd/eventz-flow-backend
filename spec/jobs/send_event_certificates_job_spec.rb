require 'rails_helper'

RSpec.describe SendEventCertificatesJob, type: :job do
  let(:event) { create(:event) }
  let!(:template) { create(:certificate_template, :ready, event: event) }

  let!(:ticket_with_email) { create(:ticket, event: event, attendee_email: 'a@example.com') }
  let!(:ticket_checked_in) { create(:ticket, :checked_in, event: event, attendee_email: 'b@example.com') }
  let!(:ticket_no_email)   { create(:ticket, event: event, attendee_email: nil) }

  describe '#perform' do
    it 'enqueues a delivery per eligible ticket (all audience)' do
      expect {
        described_class.new.perform(event.id, 'all')
      }.to have_enqueued_job(EmailDeliveryJob).twice
    end

    it 'skips tickets without an email' do
      # only ticket_with_email + ticket_checked_in have emails => 2, not 3
      expect {
        described_class.new.perform(event.id, 'all')
      }.to have_enqueued_job(EmailDeliveryJob).exactly(2).times
    end

    it 'respects the checked_in audience' do
      expect {
        described_class.new.perform(event.id, 'checked_in')
      }.to have_enqueued_job(EmailDeliveryJob).once
    end

    it 'respects manual exclusions' do
      expect {
        described_class.new.perform(event.id, 'all', [ticket_with_email.public_id])
      }.to have_enqueued_job(EmailDeliveryJob).once
    end

    it 'does nothing when the template is not ready' do
      template.update_column(:status, CertificateTemplate.statuses[:draft])
      expect {
        described_class.new.perform(event.id, 'all')
      }.not_to have_enqueued_job(EmailDeliveryJob)
    end

    it 'does nothing when the event is missing' do
      expect {
        described_class.new.perform(-1, 'all')
      }.not_to have_enqueued_job(EmailDeliveryJob)
    end
  end

  describe '.recipient_scope' do
    it 'excludes blank-email tickets' do
      ids = described_class.recipient_scope(event, 'all').pluck(:id)
      expect(ids).to contain_exactly(ticket_with_email.id, ticket_checked_in.id)
    end

    context 'unsent audience' do
      it 'excludes tickets that already have an in-flight/sent certificate' do
        create(:email_delivery,
               related: ticket_with_email,
               mailer_name: 'CertificateMailer',
               mailer_action: 'certificate_email',
               status: 'sent')

        ids = described_class.recipient_scope(event, 'unsent').pluck(:id)
        expect(ids).to contain_exactly(ticket_checked_in.id)
      end

      it 'includes tickets whose only certificate delivery failed' do
        create(:email_delivery,
               related: ticket_with_email,
               mailer_name: 'CertificateMailer',
               mailer_action: 'certificate_email',
               status: 'failed')

        ids = described_class.recipient_scope(event, 'unsent').pluck(:id)
        expect(ids).to include(ticket_with_email.id)
      end
    end
  end
end
