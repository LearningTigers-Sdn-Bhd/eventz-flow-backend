require 'rails_helper'

RSpec.describe EventReminderJob, type: :job do
  describe '#perform' do
    let(:event) do
      create(:event,
        start_date: 7.days.from_now.to_date,
        reminders_enabled: true,
        reminder_7_day: true,
        reminder_1_day: true
      )
    end
    let(:ticket) { create(:ticket, event: event, attendee_email: "test@example.com") }

    before { ticket }

    it 'sends 7-day reminder for events starting in 7 days' do
      expect {
        described_class.new.perform
      }.to have_enqueued_mail(EventReminderMailer, :reminder).with(ticket, event, "7_day")
    end

    it 'creates a reminder log' do
      expect {
        described_class.new.perform
      }.to change(EventReminderLog, :count).by(1)
    end

    it 'does not send duplicate reminders' do
      create(:event_reminder_log, event: event, ticket: ticket, reminder_type: "7_day")

      expect {
        described_class.new.perform
      }.not_to have_enqueued_mail(EventReminderMailer, :reminder)
    end

    context 'when reminders are disabled' do
      before { event.update!(reminders_enabled: false) }

      it 'does not send reminders' do
        expect {
          described_class.new.perform
        }.not_to have_enqueued_mail(EventReminderMailer, :reminder)
      end
    end

    context 'when ticket has no email' do
      before { ticket.update!(attendee_email: nil) }

      it 'does not send reminder' do
        expect {
          described_class.new.perform
        }.not_to have_enqueued_mail(EventReminderMailer, :reminder)
      end
    end
  end
end
