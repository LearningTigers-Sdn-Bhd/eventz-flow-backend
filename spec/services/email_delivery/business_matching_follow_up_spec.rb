require 'rails_helper'

RSpec.describe EmailDelivery::BusinessMatchingFollowUp do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_business_matching: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, attendee_email: 'attendee@example.com') }

  def enable_for(ticket_type_ids)
    event.create_event_email_setting!(business_matching_ticket_type_ids: ticket_type_ids)
  end

  describe '.enqueue_after' do
    it 'does nothing when no event_email_setting exists yet' do
      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'does nothing when the ticket type is not in the opted-in list' do
      enable_for([ticket_type.id + 999])

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'enqueues business_matching_email when the ticket type is opted in' do
      enable_for([ticket_type.id])

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.to change(EmailDelivery, :count).by(1)

      delivery = EmailDelivery.last
      expect(delivery.mailer_name).to eq('TicketMailer')
      expect(delivery.mailer_action).to eq('business_matching_email')
      expect(delivery.related).to eq(ticket)
    end

    it 'also chains off group_confirmation_email' do
      enable_for([ticket_type.id])

      expect do
        described_class.enqueue_after('TicketMailer', 'group_confirmation_email', [ticket])
      end.to change(EmailDelivery, :count).by(1)
    end

    it 'does nothing when the event has business matching disabled' do
      event.update!(use_business_matching: false)
      enable_for([ticket_type.id])

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'ignores mailer actions outside the chain' do
      enable_for([ticket_type.id])

      expect do
        described_class.enqueue_after('TicketMailer', 'payment_pending_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'ignores other mailers entirely' do
      enable_for([ticket_type.id])

      expect do
        described_class.enqueue_after('CertificateMailer', 'certificate_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'does nothing when the attendee has no email' do
      enable_for([ticket_type.id])
      ticket.update_column(:attendee_email, nil)

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end
  end

  describe 'wired through AuditedDelivery.deliver_later' do
    it 'chains the business matching email after a real confirmation_email send' do
      enable_for([ticket_type.id])
      clear_enqueued_jobs

      expect do
        EmailDelivery::AuditedDelivery.deliver_later(
          mailer_name: 'TicketMailer',
          mailer_action: 'confirmation_email',
          args: [ticket],
          related: ticket
        )
      end.to change(EmailDelivery, :count).by(2)

      actions = EmailDelivery.order(:id).last(2).map(&:mailer_action)
      expect(actions).to contain_exactly('confirmation_email', 'business_matching_email')
    end

    it 'respects the business_matching_invite toggle independently of the ticket-type list' do
      enable_for([ticket_type.id])
      event.event_email_setting.update!(disabled_categories: ['business_matching_invite'])
      clear_enqueued_jobs

      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket
      )

      delivery = EmailDelivery.find_by(mailer_action: 'business_matching_email')
      expect(delivery.status).to eq('skipped')
    end

    it 'runs independently of the voucher follow-up chain' do
      create(:voucher, event: event)
      enable_for([ticket_type.id])
      clear_enqueued_jobs

      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket
      )

      actions = EmailDelivery.where(related: ticket).pluck(:mailer_action)
      expect(actions).to contain_exactly('confirmation_email', 'voucher_showcase_email', 'business_matching_email')
    end
  end
end
