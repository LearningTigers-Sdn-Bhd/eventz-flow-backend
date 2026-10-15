class PendingPaymentReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    current_period_key = Date.current.strftime('%G-W%V')

    eligible_tickets(current_period_key)
      .group_by { |ticket| [ticket.event_id, ticket.attendee_email] }
      .each_value do |tickets|
        actionable = tickets.select do |ticket|
          actionable = false

          ticket.with_lock do
            current_log = current_period_log_for(ticket, current_period_key)
            actionable = actionable_ticket?(ticket) && current_log&.status != 'sent'
          end

          actionable
        end

        next if actionable.empty?

        error = send_and_log(actionable, current_period_key)
        raise error if error
      end
  end

  private

  def eligible_tickets(period_key)
    sent_ticket_ids = EventReminderLog.sent
                                      .where(reminder_type: 'payment_pending_weekly', reminder_period_key: period_key)
                                      .select(:ticket_id)

    Ticket.joins(:event)
          .includes(:event, :ticket_type)
          .where(payment_status: :pending)
          .where(waiting_list: false)
          .where.not(status: %i[canceled refunded])
          .where.not(attendee_email: [nil, ''])
          .where('events.start_date > ?', Time.current)
          .where.not(id: sent_ticket_ids)
  end

  def actionable_ticket?(ticket)
    ticket.pending? && !ticket.canceled? && !ticket.refunded? &&
      ticket.attendee_email.present? &&
      ticket.ticket_type.current_price.positive? &&
      ticket.event.reload.start_date > Time.current
  end

  def current_period_log_for(ticket, period_key)
    ticket.event_reminder_logs.find_by(
      reminder_type: 'payment_pending_weekly',
      reminder_period_key: period_key
    )
  end

  # tickets share one (event, attendee_email) — one batched email covers
  # all of them; a single-ticket group falls back to the existing
  # per-ticket mailer action, unchanged.
  def send_and_log(tickets, period_key)
    event = tickets.first.event

    tickets.each do |ticket|
      log = current_period_log_for(ticket, period_key) || EventReminderLog.new(
        event: event,
        ticket: ticket,
        reminder_type: 'payment_pending_weekly',
        reminder_period_key: period_key
      )
      log.update!(sent_at: Time.current, status: 'sent')
    end

    if tickets.size > 1
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'EventReminderMailer',
        mailer_action: 'group_pending_payment_reminder',
        args: [tickets, event],
        related: tickets.first,
        metadata: {
          event_id: event.id,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: period_key
        }
      )
    else
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'EventReminderMailer',
        mailer_action: 'pending_payment_reminder',
        args: [tickets.first, event],
        related: tickets.first,
        metadata: {
          event_id: event.id,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: period_key
        }
      )
    end
    nil
  rescue StandardError => e
    tickets.each do |ticket|
      failed_log = current_period_log_for(ticket, period_key)

      if failed_log
        failed_log.update!(status: 'failed', sent_at: nil)
      else
        EventReminderLog.create!(
          event: ticket.event,
          ticket: ticket,
          reminder_type: 'payment_pending_weekly',
          reminder_period_key: period_key,
          sent_at: nil,
          status: 'failed'
        )
      end
    end

    Rails.logger.error("Pending payment reminder failed for tickets #{tickets.map(&:id).join(', ')}: #{e.message}")
    e
  end
end
