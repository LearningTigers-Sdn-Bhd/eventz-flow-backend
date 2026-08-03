require 'rails_helper'

RSpec.describe PendingPaymentReminderJob, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now }

  let(:today) { Date.new(2026, 4, 9) }
  let(:current_time) { Time.zone.local(2026, 4, 9, 12, 0, 0) }
  let(:period_key) { format('%<year>d-W%<week>02d', year: today.cwyear, week: today.cweek) }
  let(:event_start_date) { today + 3.days }
  let(:event) do
    create(
      :event,
      start_date: event_start_date,
      end_date: event_start_date + 2.hours
    )
  end
  let!(:ticket) { create(:ticket, :pending_payment, event: event, attendee_email: 'pending@example.com') }

  before do
    clear_enqueued_jobs
    allow(Date).to receive(:current).and_return(today)
    allow(Time).to receive(:current).and_return(current_time)
  end

  after { clear_enqueued_jobs }

  describe '#perform' do
    it 'enqueues a reminder for eligible pending payment tickets' do
      expect do
        perform_job
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    it 'skips a same-week rerun when a weekly pending payment reminder log already exists' do
      create(
        :event_reminder_log,
        :payment_pending_weekly,
        event: event,
        ticket: ticket,
        reminder_period_key: period_key
      )

      expect do
        perform_job
      end.not_to have_enqueued_job(EmailDeliveryJob)
    end

    it 'allows a reminder in a later week' do
      create(
        :event_reminder_log,
        :payment_pending_weekly,
        event: event,
        ticket: ticket,
        reminder_period_key: '2026-W14'
      )

      expect do
        perform_job
      end.to have_enqueued_job(EmailDeliveryJob)
    end

    context 'when the mailer delivery is stubbed' do
      before do
        allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later).and_return(create(:email_delivery))
      end

      it 'retries after a same-week failed reminder log and marks it sent' do
        failed_log = create(
          :event_reminder_log,
          :payment_pending_weekly,
          event: event,
          ticket: ticket,
          reminder_period_key: period_key,
          status: 'failed',
          sent_at: nil
        )

        expect do
          perform_job
        end.not_to change(EventReminderLog, :count)

        failed_log.reload
        expect(failed_log.status).to eq('sent')
        expect(failed_log.sent_at).to be_present
      end

      context 'when enqueueing raises' do
        before do
          allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later).and_raise(StandardError, 'enqueue failed')
        end

        it 'marks the current-week log failed' do
          failed_log = create(
            :event_reminder_log,
            :payment_pending_weekly,
            event: event,
            ticket: ticket,
            reminder_period_key: period_key,
            status: 'failed',
            sent_at: nil
          )

          expect { perform_job }.to raise_error(StandardError, 'enqueue failed')

          failed_log.reload
          expect(failed_log.status).to eq('failed')
          expect(failed_log.sent_at).to be_nil
        end

        it 'creates a failed current-week log without sent_at when no log exists yet' do
          expect { perform_job }.to raise_error(StandardError, 'enqueue failed')

          failed_log = EventReminderLog.find_by!(
            ticket: ticket,
            reminder_type: 'payment_pending_weekly',
            reminder_period_key: period_key
          )
          expect(failed_log.status).to eq('failed')
          expect(failed_log.sent_at).to be_nil
        end
      end
    end

    context 'when the ticket has no attendee email' do
      let!(:ticket) { create(:ticket, :pending_payment, event: event, attendee_email: nil) }

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket status is purchased but payment is still pending' do
      let!(:ticket) do
        create(:ticket, event: event, attendee_email: 'purchased@example.com', payment_status: :pending,
                        status: :purchased)
      end

      it 'still sends the reminder' do
        expect do
          perform_job
        end.to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket payment status is paid' do
      let!(:ticket) { create(:ticket, :pending_payment, :paid, event: event, attendee_email: 'paid@example.com') }

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket is on the waiting list' do
      let!(:ticket) do
        create(:ticket, :pending_payment, event: event, attendee_email: 'waiting@example.com', waiting_list: true)
      end

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket payment status is failed' do
      let!(:ticket) do
        create(:ticket, event: event, attendee_email: 'failed@example.com', payment_status: :failed, status: :purchased)
      end

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket status is canceled with pending payment' do
      let!(:ticket) do
        create(:ticket, event: event, attendee_email: 'canceled@example.com', payment_status: :pending,
                        status: :canceled)
      end

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the ticket status is refunded with pending payment' do
      let!(:ticket) do
        create(:ticket, event: event, attendee_email: 'refunded@example.com', payment_status: :pending,
                        status: :refunded)
      end

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the event has already started' do
      let(:event_start_date) { today - 1.day }

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_job(EmailDeliveryJob)
      end
    end

    context 'when the event started earlier today' do
      let(:event_start_date) { Time.zone.local(2026, 4, 9, 8, 0, 0) }

      it 'skips the reminder' do
        expect do
          perform_job
        end.not_to have_enqueued_mail(EventReminderMailer, :pending_payment_reminder)
      end
    end

    context 'when the ticket becomes non-actionable before the lock-time send' do
      before do
        allow_any_instance_of(Ticket).to receive(:with_lock).and_wrap_original do |original, *args, &block|
          ticket.update!(payment_status: :paid)
          original.call(*args, &block)
        end
      end

      it 'skips the reminder after re-checking inside the lock' do
        expect do
          perform_job
        end.not_to have_enqueued_mail(EventReminderMailer, :pending_payment_reminder)

        expect(
          EventReminderLog.where(
            ticket: ticket,
            reminder_type: 'payment_pending_weekly',
            reminder_period_key: period_key
          )
        ).to be_empty
      end
    end
  end
end
