class PendingPaymentReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    current_period_key = Date.current.strftime('%G-W%V')

    eligible_tickets(current_period_key).find_each do |ticket|
      error = nil

      ticket.with_lock do
        next unless actionable_ticket?(ticket)

        current_log = current_period_log_for(ticket, current_period_key)
        next if current_log&.status == 'sent'

        error = send_and_log(ticket, current_period_key, current_log)
      end

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

  def send_and_log(ticket, period_key, current_log)
    event = ticket.event

    log = current_log || EventReminderLog.new(
      event: event,
      ticket: ticket,
      reminder_type: 'payment_pending_weekly',
      reminder_period_key: period_key
    )
    log.update!(sent_at: Time.current, status: 'sent')

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'EventReminderMailer',
      mailer_action: 'pending_payment_reminder',
      args: [ticket, event],
      related: ticket,
      metadata: {
        event_id: event.id,
        reminder_type: 'payment_pending_weekly',
        reminder_period_key: period_key
      }
    )
    nil
  rescue StandardError => e
    failed_log = current_log || current_period_log_for(ticket, period_key)

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

    Rails.logger.error("Pending payment reminder failed for ticket #{ticket.id}: #{e.message}")
    e
  end
end
