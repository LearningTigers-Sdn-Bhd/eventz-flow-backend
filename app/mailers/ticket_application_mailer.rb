class TicketApplicationMailer < ApplicationMailer
  def acknowledgement(ticket_application)
    set_context(ticket_application)

    mail(
      to: @ticket.attendee_email,
      from: sender_from,
      bcc: payment_receipt_bcc(additional: @event.event_email_setting&.payment_receipt_email),
      subject: "Application received for #{@event.title}"
    )
  end

  def rsvp_invitation(ticket_application, raw_token)
    set_context(ticket_application)
    @rsvp_url = rsvp_url(raw_token)

    mail(
      to: @ticket.attendee_email,
      from: sender_from,
      subject: "RSVP required for #{@event.title}"
    )
  end

  def rejection(ticket_application)
    set_context(ticket_application)

    mail(
      to: @ticket.attendee_email,
      from: sender_from,
      subject: "Application update for #{@event.title}"
    )
  end

  private

  def set_context(ticket_application)
    @ticket_application = ticket_application
    @ticket = ticket_application.ticket
    @event = @ticket.event
    @ticket_type = @ticket.ticket_type
    @setting = ticket_application.registration_form.registration_form_rsvp_setting
    @contact_email = @event.event_email_setting&.contact_email.presence
  end

  def sender_from
    setting = @event.event_email_setting
    address = setting&.sender_address.presence || 'notifications@updates.eventzflow.com'
    name = setting&.sender_name.presence || @event.title
    "#{name} <#{address}>"
  end

  def rsvp_url(raw_token)
    base_url = ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
    "#{base_url}/event/#{@event.slug}/ticket-rsvp/#{raw_token}"
  end
end
