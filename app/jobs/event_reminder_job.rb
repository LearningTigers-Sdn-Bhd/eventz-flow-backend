class EventReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    send_reminders("7_day", 7.days.from_now.to_date)
    send_reminders("1_day", 1.day.from_now.to_date)
  end

  private

  def send_reminders(reminder_type, target_date)
    reminder_column = reminder_type == "7_day" ? :reminder_7_day : :reminder_1_day

    events = Event.where(reminders_enabled: true)
                  .where(reminder_column => true)
                  .where(start_date: target_date.beginning_of_day..target_date.end_of_day)

    events.find_each do |event|
      event.tickets
        .left_outer_joins(:ticket_application)
        .where(payment_status: :paid, status: %i[purchased scanned])
        .where(waiting_list: false)
        .where(ticket_applications: { id: nil })
        .or(
          event.tickets
            .left_outer_joins(:ticket_application)
            .where(payment_status: :paid, status: %i[purchased scanned])
            .where(waiting_list: false)
            .where(ticket_applications: { review_status: TicketApplication.review_statuses[:approved] })
        )
        .where.not(attendee_email: [nil, ''])
        .find_each do |ticket|
        next if already_sent?(ticket, reminder_type)
        send_and_log(ticket, event, reminder_type)
      end
    end
  end

  def already_sent?(ticket, reminder_type)
    EventReminderLog.exists?(ticket: ticket, reminder_type: reminder_type)
  end

  def send_and_log(ticket, event, reminder_type)
    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'EventReminderMailer',
      mailer_action: 'reminder',
      args: [ticket, event, reminder_type],
      related: ticket,
      metadata: { event_id: event.id, reminder_type: reminder_type }
    )

    EventReminderLog.create!(
      event: event,
      ticket: ticket,
      reminder_type: reminder_type,
      status: "sent",
      sent_at: Time.current
    )
  rescue StandardError => e
    EventReminderLog.create!(
      event: event,
      ticket: ticket,
      reminder_type: reminder_type,
      status: "failed"
    )
    Rails.logger.error("Reminder failed for ticket #{ticket.id}: #{e.message}")
  end
end
