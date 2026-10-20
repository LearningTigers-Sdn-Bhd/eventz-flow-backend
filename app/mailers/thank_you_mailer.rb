class ThankYouMailer < ApplicationMailer
  # Only link when the organizer opted in AND there's an active, non-empty form to land on.
  def self.feedback_link_available?(event, audience: :ticket)
    form = audience.to_sym == :exhibitor ? event.exhibitor_feedback_form : event.feedback_form
    !!(event.event_email_setting&.thank_you_include_feedback && form&.is_active? && form.feedback_questions.exists?)
  end

  def thank_you_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @sender_name = email_setting&.sender_name.presence || @event.title
    @contact_email = email_setting&.contact_email.presence
    @feedback_url = feedback_url
    template = @event.certificate_template_for(ticket)
    @certificate_for_feedback = @feedback_url.present? && template&.ready? && template.require_feedback

    mail(
      to: ticket.attendee_email,
      from: format_sender(@sender_name, email_setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS),
      subject: "Thank you for joining #{@event.title}"
    )
  end

  # Nudge for attendees who got the thank-you but haven't filled in the form.
  def feedback_reminder_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @sender_name = email_setting&.sender_name.presence || @event.title
    @contact_email = email_setting&.contact_email.presence
    @feedback_url = feedback_url

    mail(
      to: ticket.attendee_email,
      from: format_sender(@sender_name, email_setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS),
      subject: "Quick reminder: share your feedback on #{@event.title}"
    )
  end

  # Exhibitor variants: one email per company, however many kits or booths it has.
  def exhibitor_thank_you_email(exhibitor)
    load_exhibitor(exhibitor)

    mail(
      to: @recipient_email,
      from: format_sender(@sender_name, email_setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS),
      subject: "Thank you for exhibiting at #{@event.title}"
    )
  end

  def exhibitor_feedback_reminder_email(exhibitor)
    load_exhibitor(exhibitor)

    mail(
      to: @recipient_email,
      from: format_sender(@sender_name, email_setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS),
      subject: "Quick reminder: share your feedback on #{@event.title}"
    )
  end

  private

  def load_exhibitor(exhibitor)
    @exhibitor = exhibitor
    @event = exhibitor.event
    @company = ExhibitorCertificate.new(exhibitor)
    @company_name = @company.company_name.presence || 'exhibitor'
    @recipient_email = @company.email
    @sender_name = email_setting&.sender_name.presence || @event.title
    @contact_email = email_setting&.contact_email.presence
    @feedback_url = feedback_url_for(:exhibitor)
  end

  def email_setting
    @event.event_email_setting
  end

  def feedback_url
    feedback_url_for(:ticket)
  end

  def feedback_url_for(audience)
    return unless self.class.feedback_link_available?(@event, audience:)

    audience == :exhibitor ? FeedbackLink.exhibitor(@event, @exhibitor) : FeedbackLink.ticket(@event, @ticket)
  end
end
