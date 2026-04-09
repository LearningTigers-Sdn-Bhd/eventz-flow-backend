require 'rails_helper'

RSpec.describe EventReminderLog, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:ticket) }
  end

  describe 'validations' do
    let(:event) { create(:event) }
    let(:ticket) { create(:ticket, event: event) }
    let(:timestamps) { { created_at: Time.current, updated_at: Time.current } }

    subject { create(:event_reminder_log, event: event, ticket: ticket) }

    it { should validate_presence_of(:reminder_type) }
    it { should validate_inclusion_of(:reminder_type).in_array(%w[7_day 1_day payment_pending_weekly]) }
    it { should validate_inclusion_of(:status).in_array(%w[sent failed]) }

    describe 'legacy reminders' do
      it 'normalizes blank reminder_period_key to nil for 7_day reminders' do
        reminder_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: '7_day',
          reminder_period_key: ''
        )

        reminder_log.validate

        expect(reminder_log.reminder_period_key).to be_nil
      end

      it 'rejects reminder_period_key for 7_day reminders' do
        reminder_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: '7_day',
          reminder_period_key: '2026-W15'
        )

        expect(reminder_log).to be_invalid
        expect(reminder_log.errors[:reminder_period_key]).to include('must be blank')
      end

      it 'rejects duplicate 7_day reminder logs for the same ticket' do
        create(:event_reminder_log, event: event, ticket: ticket, reminder_type: '7_day')

        duplicate_log = build(:event_reminder_log, event: event, ticket: ticket, reminder_type: '7_day')

        expect(duplicate_log).to be_invalid
        expect(duplicate_log.errors[:ticket_id]).to include('has already been taken')
      end

      it 'enforces uniqueness for 7_day reminder logs at the database level' do
        create(:event_reminder_log, event: event, ticket: ticket, reminder_type: '7_day')

        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: '7_day',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: nil
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'rejects 7_day reminder logs with reminder_period_key at the database level' do
        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: '7_day',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: '2026-W15'
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    describe 'payment_pending_weekly reminders' do
      it 'strips surrounding whitespace from reminder_period_key' do
        reminder_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: ' 2026-W15 '
        )

        reminder_log.validate

        expect(reminder_log.reminder_period_key).to eq('2026-W15')
      end

      it 'allows payment_pending_weekly as a reminder_type when reminder_period_key is present' do
        reminder_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W15'
        )

        expect(reminder_log).to be_valid
      end

      it 'requires reminder_period_key' do
        reminder_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: nil
        )

        expect(reminder_log).to be_invalid
        expect(reminder_log.errors[:reminder_period_key]).to include("can't be blank")
      end

      it 'rejects duplicate weekly reminder logs for the same ticket and period' do
        create(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W15'
        )

        duplicate_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W15'
        )

        expect(duplicate_log).to be_invalid
        expect(duplicate_log.errors[:ticket_id]).to include('has already been taken')
      end

      it 'allows weekly reminder logs for the same ticket in different periods' do
        create(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W15'
        )

        next_period_log = build(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W16'
        )

        expect(next_period_log).to be_valid
      end

      it 'enforces uniqueness for weekly reminder logs at the database level' do
        create(
          :event_reminder_log,
          event: event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: '2026-W15'
        )

        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: 'payment_pending_weekly',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: '2026-W15'
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'rejects weekly reminder logs without reminder_period_key at the database level' do
        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: 'payment_pending_weekly',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: nil
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::StatementInvalid)
      end

      it 'rejects weekly reminder logs with blank reminder_period_key at the database level' do
        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: 'payment_pending_weekly',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: ''
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::StatementInvalid)
      end

      it 'rejects weekly reminder logs with whitespace-padded reminder_period_key at the database level' do
        expect do
          described_class.insert_all!(
            [{
              event_id: event.id,
              ticket_id: ticket.id,
              reminder_type: 'payment_pending_weekly',
              status: 'sent',
              sent_at: Time.current,
              reminder_period_key: ' 2026-W15 '
            }.merge(timestamps)]
          )
        end.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end
end
