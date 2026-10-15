class EventReminderMailer < ApplicationMailer
  def reminder(ticket, event, reminder_type)
    @ticket = ticket
    @event = event
    @reminder_type = reminder_type
    @days_until = reminder_type == '7_day' ? 7 : 1

    # Generate QR code and attach inline
    qr_png = QrCodeService.generate_png(ticket.public_id)
    attachments.inline['qr_code.png'] = qr_png

    mail(
      to: ticket.attendee_email,
      subject: reminder_subject
    )
  end

  # Batched variant for tickets sharing one recipient email (group
  # registration) — one reminder listing every ticket instead of N.
  def group_reminder(tickets, event, reminder_type)
    @tickets = tickets
    @event = event
    @reminder_type = reminder_type
    @days_until = reminder_type == '7_day' ? 7 : 1

    @tickets.each_with_index do |ticket, index|
      attachments.inline["qr_code_#{index}.png"] = QrCodeService.generate_png(ticket.public_id)
    end

    mail(
      to: @tickets.first.attendee_email,
      subject: reminder_subject
    )
  end

  def pending_payment_reminder(ticket, event)
    @ticket = ticket
    @event = event

    mail(
      to: ticket.attendee_email,
      subject: "Complete your payment for #{event.title}"
    )
  end

  # Batched variant for pending tickets sharing one recipient email.
  def group_pending_payment_reminder(tickets, event)
    @tickets = tickets
    @event = event

    mail(
      to: @tickets.first.attendee_email,
      subject: "Complete your payment for #{event.title}"
    )
  end

  private

  def reminder_subject
    if @days_until == 1
      "See you tomorrow at #{@event.title}!"
    else
      "#{@days_until} days until #{@event.title}"
    end
  end
end
