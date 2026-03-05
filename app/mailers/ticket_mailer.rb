class TicketMailer < ApplicationMailer
  def confirmation_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @ticket_type = ticket.ticket_type
    @ticket_payment = ticket.ticket_payment
    amount_paid = (@ticket_payment&.amount || @ticket_type.current_price).to_f
    @show_payment_receipt = ticket.paid? && amount_paid.positive?
    bcc_recipients = @show_payment_receipt ? payment_receipt_bcc(additional: ticket.event.payment_receipt_email) : nil

    # Generate QR code and attach inline
    qr_png = QrCodeService.generate_png(ticket.public_id, size: 600)
    attachments.inline['qr_code.png'] = qr_png

    mail(
      to: ticket.attendee_email,
      from: 'OGSE Sabah 2026 Secretariat <ogsesabah.secretariat@updates.eventzflow.com>',
      bcc: bcc_recipients.presence,
      subject: "Your ticket for #{@event.title}"
    )
  end
end
