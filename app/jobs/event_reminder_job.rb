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
      candidate_tickets(event)
        .reject { |ticket| already_sent?(ticket, reminder_type) }
        .group_by(&:attendee_email)
        .each_value { |tickets| send_and_log(tickets, event, reminder_type) }
    end
  end

  def candidate_tickets(event)
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
      .to_a
  end

  def already_sent?(ticket, reminder_type)
    EventReminderLog.exists?(ticket: ticket, reminder_type: reminder_type)
  end

  # tickets share one attendee_email (group registration) — one batched
  # email covers all of them; a single-ticket group falls back to the
  # existing per-ticket mailer action, unchanged.
  def send_and_log(tickets, event, reminder_type)
    if tickets.size > 1
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'EventReminderMailer',
        mailer_action: 'group_reminder',
        args: [tickets, event, reminder_type],
        related: tickets.first,
        metadata: { event_id: event.id, reminder_type: reminder_type }
      )
    else
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'EventReminderMailer',
        mailer_action: 'reminder',
        args: [tickets.first, event, reminder_type],
        related: tickets.first,
        metadata: { event_id: event.id, reminder_type: reminder_type }
      )
    end

    tickets.each do |ticket|
      EventReminderLog.create!(
        event: event,
        ticket: ticket,
        reminder_type: reminder_type,
        status: "sent",
        sent_at: Time.current
      )
    end
  rescue StandardError => e
    tickets.each do |ticket|
      EventReminderLog.create!(
        event: event,
        ticket: ticket,
        reminder_type: reminder_type,
        status: "failed"
      )
    end
    Rails.logger.error("Reminder failed for tickets #{tickets.map(&:id).join(', ')}: #{e.message}")
  end
end
