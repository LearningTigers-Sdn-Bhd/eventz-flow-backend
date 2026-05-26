class TicketMailer < ApplicationMailer
  def confirmation_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @ticket_type = ticket.ticket_type
    @ticket_payment = ticket.ticket_payment
    @borneo_upgrade_ticket = borneo_upgrade_ticket?
    amount_paid = (@ticket_payment&.amount || @ticket_type.current_price).to_f
    @show_payment_receipt = ticket.paid? && amount_paid.positive?
    bcc_recipients = payment_receipt_bcc(additional: email_setting&.payment_receipt_email)
    set_email_config

    # Generate QR code and attach inline
    qr_png = QrCodeService.generate_png(ticket.public_id, size: 600)
    attachments.inline['qr_code.png'] = qr_png

    mail(
      to: ticket.attendee_email,
      from: sender_from,
      bcc: bcc_recipients.presence,
      subject: "Your ticket for #{@event.title}"
    )
  end

  private

  def email_setting
    @event.event_email_setting
  end

  def set_email_config
    @sender_name = email_setting&.sender_name.presence || @event.title
    @contact_email = email_setting&.contact_email.presence
  end

  def sender_from
    address = email_setting&.sender_address.presence || 'notifications@updates.eventzflow.com'
    name = email_setting&.sender_name.presence || @event.title
    "#{name} <#{address}>"
  end

  def borneo_upgrade_ticket?
    @event.slug.to_s.strip.downcase.start_with?(BorneoExpoTicketUpgradeService::BORNEO_EVENT_SLUG_PREFIX) &&
      @ticket_type.name.to_s.include?('Exhibitor & Conference')
  end
end
