require 'rails_helper'

RSpec.describe EmailDelivery::VoucherFollowUp do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_voucher: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type, attendee_email: 'attendee@example.com') }

  describe '.enqueue_after' do
    it 'does nothing when the event has no active vouchers' do
      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'enqueues voucher_showcase_email when the event has an active voucher' do
      create(:voucher, event: event)

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.to change(EmailDelivery, :count).by(1)

      delivery = EmailDelivery.last
      expect(delivery.mailer_name).to eq('TicketMailer')
      expect(delivery.mailer_action).to eq('voucher_showcase_email')
      expect(delivery.related).to eq(ticket)
    end

    it 'also chains off group_confirmation_email' do
      create(:voucher, event: event)

      expect do
        described_class.enqueue_after('TicketMailer', 'group_confirmation_email', [ticket])
      end.to change(EmailDelivery, :count).by(1)
    end

    context 'when several tickets share one email' do
      let(:sibling) do
        create(:ticket, event: event, ticket_type: ticket_type, attendee_email: 'Attendee@Example.com')
      end

      before { create(:voucher, event: event) }

      def voucher_emails
        EmailDelivery.where(mailer_action: 'voucher_showcase_email')
      end

      it 'sends the voucher email once per address, case-insensitively' do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [sibling])

        expect(voucher_emails.count).to eq(1)
      end

      it 'still sends to a different address on the same event' do
        other = create(:ticket, event: event, ticket_type: ticket_type, attendee_email: 'other@example.com')
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [other])

        expect(voucher_emails.pluck(:recipient)).to contain_exactly('attendee@example.com', 'other@example.com')
      end

      it 'still sends the same address again for a different event' do
        event2 = create(:event, use_voucher: true)
        create(:voucher, event: event2)
        other_event_ticket = create(:ticket, event: event2, ticket_type: create(:ticket_type, event: event2),
                                             attendee_email: 'attendee@example.com')
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [other_event_ticket])

        expect(voucher_emails.count).to eq(2)
      end

      it 'sends again once the earlier email is outside the dedupe window' do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
        voucher_emails.update_all(created_at: 25.hours.ago)
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [sibling])

        expect(voucher_emails.count).to eq(2)
      end

      it 'does not count a failed earlier send as already sent' do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
        voucher_emails.update_all(status: 'failed')
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [sibling])

        expect(voucher_emails.count).to eq(2)
      end
    end

    it 'ignores mailer actions outside the chain' do
      create(:voucher, event: event)

      expect do
        described_class.enqueue_after('TicketMailer', 'payment_pending_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'ignores other mailers entirely' do
      create(:voucher, event: event)

      expect do
        described_class.enqueue_after('CertificateMailer', 'certificate_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'does nothing when the event has vouchers disabled' do
      voucher_off_event = create(:event, use_voucher: false)
      voucher_off_ticket_type = create(:ticket_type, event: voucher_off_event)
      voucher_off_ticket = create(:ticket, event: voucher_off_event, ticket_type: voucher_off_ticket_type,
                                            attendee_email: 'off@example.com')
      create(:voucher, event: voucher_off_event)

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [voucher_off_ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'does nothing when only inactive vouchers exist' do
      create(:voucher, event: event, status: :inactive)

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end

    it 'does nothing when the attendee has no email' do
      create(:voucher, event: event)
      ticket.update_column(:attendee_email, nil)

      expect do
        described_class.enqueue_after('TicketMailer', 'confirmation_email', [ticket])
      end.not_to change(EmailDelivery, :count)
    end
  end

  describe 'wired through AuditedDelivery.deliver_later' do
    it 'chains the voucher email after a real confirmation_email send' do
      create(:voucher, event: event)
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
      expect(actions).to contain_exactly('confirmation_email', 'voucher_showcase_email')
    end

    it 'sends one voucher email when three tickets on one address each get a confirmation' do
      create(:voucher, event: event)
      tickets = [ticket, *create_list(:ticket, 2, event: event, ticket_type: ticket_type,
                                                  attendee_email: 'attendee@example.com')]
      clear_enqueued_jobs

      tickets.each do |t|
        EmailDelivery::AuditedDelivery.deliver_later(
          mailer_name: 'TicketMailer', mailer_action: 'confirmation_email', args: [t], related: t
        )
      end

      expect(EmailDelivery.where(mailer_action: 'confirmation_email').count).to eq(3)
      expect(EmailDelivery.where(mailer_action: 'voucher_showcase_email').count).to eq(1)
    end

    it 'respects the voucher_showcase toggle independently of confirmation_email' do
      create(:voucher, event: event)
      event.create_event_email_setting!(disabled_categories: ['voucher_showcase'])
      clear_enqueued_jobs

      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket
      )

      voucher_delivery = EmailDelivery.find_by(mailer_action: 'voucher_showcase_email')
      expect(voucher_delivery.status).to eq('skipped')
    end
  end
end
