class ExhibitorRegistrationMailer < ApplicationMailer
  def registration_received_email(exhibitor_kit)
    @exhibitor_kit = exhibitor_kit
    @event = exhibitor_kit.event
    @booth_label = exhibitor_kit.exhibitor_booth_price&.label || exhibitor_kit.booth_type.humanize

    mail(
      to: exhibitor_kit.pic_email_address,
      from: 'OGSE Sabah 2026 Secretariat <ogsesabah.secretariat@updates.eventzflow.com>',
      subject: "Exhibitor registration received for #{@event.title}"
    )
  end

  def payment_confirmed_email(exhibitor_kit)
    @exhibitor_kit = exhibitor_kit
    @event = exhibitor_kit.event
    @booth_label = exhibitor_kit.exhibitor_booth_price&.label || exhibitor_kit.booth_type.humanize
    @exhibitor_payment = exhibitor_kit.exhibitor_registration_payment

    mail(
      to: exhibitor_kit.pic_email_address,
      from: 'OGSE Sabah 2026 Secretariat <ogsesabah.secretariat@updates.eventzflow.com>',
      bcc: payment_receipt_bcc(additional: exhibitor_kit.event.payment_receipt_email),
      subject: "Exhibitor payment confirmed for #{@event.title}"
    )
  end
end
