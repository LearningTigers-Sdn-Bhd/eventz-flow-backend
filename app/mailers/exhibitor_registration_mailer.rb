class ExhibitorRegistrationMailer < ApplicationMailer
  def registration_received_email(exhibitor_kit)
    @exhibitor_kit = exhibitor_kit
    @event = exhibitor_kit.event
    @booth_label = exhibitor_kit.exhibitor_booth_price&.label || exhibitor_kit.booth_type.humanize
    set_email_config

    mail(
      to: exhibitor_kit.pic_email_address,
      from: sender_from,
      subject: "Exhibitor registration received for #{@event.title}"
    )
  end

  def payment_confirmed_email(exhibitor_kit)
    @exhibitor_kit = exhibitor_kit
    @event = exhibitor_kit.event
    @booth_label = exhibitor_kit.exhibitor_booth_price&.label || exhibitor_kit.booth_type.humanize
    @exhibitor_payment = exhibitor_kit.exhibitor_registration_payment
    set_email_config

    mail(
      to: exhibitor_kit.pic_email_address,
      from: sender_from,
      bcc: payment_receipt_bcc(additional: email_setting&.payment_receipt_email),
      subject: "Exhibitor payment confirmed for #{@event.title}"
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
end
