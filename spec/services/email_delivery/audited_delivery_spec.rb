require 'rails_helper'

RSpec.describe EmailDelivery::AuditedDelivery do
  include ActiveJob::TestHelper

  let(:ticket) { create(:ticket, attendee_email: 'attendee@example.com') }

  describe '.deliver_now' do
    it 'creates a sent audit row when the provider accepts the email' do
      message_delivery = TicketMailer.confirmation_email(ticket)
      allow(TicketMailer).to receive(:confirmation_email).with(ticket).and_return(message_delivery)
      allow(message_delivery).to receive(:deliver_now) do
        message_delivery.message.message_id = 'email_resend_123'
      end

      delivery = described_class.deliver_now(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket
      )

      expect(delivery).to be_persisted
      expect(delivery.status).to eq('sent')
      expect(delivery.provider_message_id).to eq('email_resend_123')
      expect(delivery.sent_at).to be_present
    end

    it 'marks the audit row failed when the provider raises' do
      message_delivery = TicketMailer.confirmation_email(ticket)
      allow(TicketMailer).to receive(:confirmation_email).with(ticket).and_return(message_delivery)
      allow(message_delivery).to receive(:deliver_now)
        .and_raise(Resend::Error::RateLimitExceededError.new('Daily email limit reached', 429, {}))

      delivery = described_class.deliver_now(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket
      )

      expect(delivery.status).to eq('failed')
      expect(delivery.failure_reason).to eq('provider_daily_limit')
      expect(delivery.next_retry_at).to be_present
    end
  end

  describe '.deliver_later' do
    it 'creates a queued row and enqueues EmailDeliveryJob' do
      clear_enqueued_jobs

      expect do
        described_class.deliver_later(
          mailer_name: 'TicketMailer',
          mailer_action: 'confirmation_email',
          args: [ticket],
          related: ticket
        )
      end.to have_enqueued_job(EmailDeliveryJob)

      expect(EmailDelivery.last.status).to eq('queued')
      expect(EmailDelivery.last.related).to eq(ticket)
    end

    it 'does not enqueue a duplicate when dedupe is on and one is already in flight' do
      clear_enqueued_jobs

      first = described_class.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket,
        dedupe: true
      )

      expect do
        second = described_class.deliver_later(
          mailer_name: 'TicketMailer',
          mailer_action: 'confirmation_email',
          args: [ticket],
          related: ticket,
          dedupe: true
        )
        expect(second.id).to eq(first.id)
      end.not_to change(EmailDelivery, :count)
    end

    it 'still enqueues duplicates when dedupe is off (default)' do
      clear_enqueued_jobs

      described_class.deliver_later(
        mailer_name: 'TicketMailer', mailer_action: 'confirmation_email', args: [ticket], related: ticket
      )

      expect do
        described_class.deliver_later(
          mailer_name: 'TicketMailer', mailer_action: 'confirmation_email', args: [ticket], related: ticket
        )
      end.to change(EmailDelivery, :count).by(1)
    end
  end

  describe 'event email toggles' do
    let(:exhibitor_kit) { create(:exhibitor_kit) }
    let(:event) { exhibitor_kit.event_vendor.event }

    it 'does not send (and does not even call the mailer) when the specific category is disabled' do
      event.create_event_email_setting!(disabled_categories: ['exhibitor_registration_received'])

      expect(ExhibitorRegistrationMailer).not_to receive(:registration_received_email)

      delivery = described_class.deliver_now(
        mailer_name: 'ExhibitorRegistrationMailer',
        mailer_action: 'registration_received_email',
        args: [exhibitor_kit],
        related: exhibitor_kit
      )

      expect(delivery.status).to eq('skipped')
    end

    it 'still sends a category NOT in disabled_categories for the same event' do
      event.create_event_email_setting!(disabled_categories: ['exhibitor_registration_received'])
      message_delivery = ExhibitorRegistrationMailer.payment_confirmed_email(exhibitor_kit)
      allow(ExhibitorRegistrationMailer).to receive(:payment_confirmed_email).and_return(message_delivery)
      allow(message_delivery).to receive(:deliver_now)

      delivery = described_class.deliver_now(
        mailer_name: 'ExhibitorRegistrationMailer',
        mailer_action: 'payment_confirmed_email',
        args: [exhibitor_kit],
        related: exhibitor_kit
      )

      expect(delivery.status).to eq('sent')
    end

    it 'blocks every category once the master switch (emails_enabled) is off, even ones not in disabled_categories' do
      event.create_event_email_setting!(emails_enabled: false, disabled_categories: [])

      expect(ExhibitorRegistrationMailer).not_to receive(:payment_confirmed_email)

      delivery = described_class.deliver_now(
        mailer_name: 'ExhibitorRegistrationMailer',
        mailer_action: 'payment_confirmed_email',
        args: [exhibitor_kit],
        related: exhibitor_kit
      )

      expect(delivery.status).to eq('skipped')
    end

    it 'via deliver_later: master switch off skips without enqueuing EmailDeliveryJob' do
      event.create_event_email_setting!(emails_enabled: false)
      clear_enqueued_jobs

      expect do
        described_class.deliver_later(
          mailer_name: 'ExhibitorRegistrationMailer',
          mailer_action: 'registration_received_email',
          args: [exhibitor_kit],
          related: exhibitor_kit
        )
      end.not_to have_enqueued_job(EmailDeliveryJob)

      expect(EmailDelivery.last.status).to eq('skipped')
    end
  end
end
