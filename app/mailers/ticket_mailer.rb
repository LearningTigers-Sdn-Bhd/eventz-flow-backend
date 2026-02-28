class TicketMailer < ApplicationMailer
  def confirmation_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @ticket_type = ticket.ticket_type
    @ticket_payment = ticket.ticket_payment
    @show_payment_receipt = ticket.paid?
    bcc_recipients = ticket.paid? ? payment_receipt_bcc(additional: ENV['ORGANIZER_PAYMENT_RECEIPT_EMAIL']) : nil

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
