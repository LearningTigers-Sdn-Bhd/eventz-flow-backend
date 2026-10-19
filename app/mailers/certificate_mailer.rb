class CertificateMailer < ApplicationMailer
  def certificate_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @template = @event.certificate_template_for(ticket)
    set_email_config

    pdf = CertificatePdfGenerator.new(@template, ticket).render
    attachments['certificate.pdf'] = { mime_type: 'application/pdf', content: pdf }

    mail(
      to: ticket.attendee_email,
      from: sender_from,
      subject: "Your certificate for #{@event.title}"
    )
  end

  def exhibitor_certificate_email(exhibitor)
    @certificate = ExhibitorCertificate.new(exhibitor)
    @event = exhibitor.event
    @template = @event.exhibitor_certificate_template
    set_email_config

    pdf = CertificatePdfGenerator.new(@template, nil, exhibitor: @certificate).render
    attachments['certificate.pdf'] = { mime_type: 'application/pdf', content: pdf }

    mail(
      to: @certificate.email,
      from: sender_from,
      subject: "Your exhibitor certificate for #{@event.title}"
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
    address = email_setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS
    name = email_setting&.sender_name.presence || @event.title
    format_sender(name, address)
  end
end
