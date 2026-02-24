class TicketMailer < ApplicationMailer
  def confirmation_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @ticket_type = ticket.ticket_type

    # Generate QR code and attach inline
    qr_png = QrCodeService.generate_png(ticket.public_id)
    attachments.inline['qr_code.png'] = qr_png

    mail(
      to: ticket.attendee_email,
      subject: "Your ticket for #{@event.title}"
    )
  end
end
