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

  def group_confirmation_email(ticket)
    @tickets = sibling_passes(ticket)
    @event = ticket.event
    set_email_config
    bcc_recipients = payment_receipt_bcc(additional: email_setting&.payment_receipt_email)

    @tickets.each_with_index do |pass, index|
      attachments.inline["qr_code_#{index}.png"] = QrCodeService.generate_png(pass.public_id, size: 600)
    end

    mail(
      to: ticket.attendee_email,
      from: sender_from,
      bcc: bcc_recipients.presence,
      subject: "Your #{@tickets.one? ? 'ticket' : 'tickets'} for #{@event.title}"
    )
  end

  def payment_pending_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @ticket_type = ticket.ticket_type
    set_email_config

    mail(
      to: ticket.attendee_email,
      from: sender_from,
      subject: "We've received your registration for #{@event.title}"
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
    format_sender(name, address)
  end

  def borneo_upgrade_ticket?
    @event.slug.to_s.strip.downcase.start_with?(BorneoExpoTicketUpgradeService::BORNEO_EVENT_SLUG_PREFIX) &&
      @ticket_type.name.to_s.include?('Exhibitor & Conference')
  end

  def sibling_passes(ticket)
    # Prefer registration_batch_id — ties QR codes to exactly this
    # submission. Old email-based match kept only for tickets predating the
    # batch id; it risked pulling in an unrelated paid purchase by the same
    # registrant (e.g. a separate table booked another day).
    if ticket.registration_batch_id.present?
      return Ticket
        .where(
          event_id: ticket.event_id,
          registration_batch_id: ticket.registration_batch_id,
          payment_status: :paid
        )
        .where.not(status: %i[canceled refunded])
        .order(:id)
        .to_a
    end

    return [ticket] if ticket.registered_by_email.blank?

    Ticket
      .where(
        event_id: ticket.event_id,
        registered_by_email: ticket.registered_by_email,
        attendee_email: ticket.attendee_email,
        payment_status: :paid
      )
      .where.not(status: %i[canceled refunded])
      .order(:id)
      .to_a
  end
end
