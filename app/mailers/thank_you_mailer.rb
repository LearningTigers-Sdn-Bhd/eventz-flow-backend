class ThankYouMailer < ApplicationMailer
  # Only link when the organizer opted in AND there's an active, non-empty form to land on.
  def self.feedback_link_available?(event)
    form = event.feedback_form
    !!(event.event_email_setting&.thank_you_include_feedback && form&.is_active? && form.feedback_questions.exists?)
  end

  def thank_you_email(ticket)
    @ticket = ticket
    @event = ticket.event
    @sender_name = email_setting&.sender_name.presence || @event.title
    @contact_email = email_setting&.contact_email.presence
    @feedback_url = feedback_url
    template = @event.certificate_template
    @certificate_for_feedback = @feedback_url.present? && template&.ready? && template.require_feedback

    mail(
      to: ticket.attendee_email,
      from: format_sender(@sender_name, email_setting&.sender_address.presence || 'notifications@updates.eventzflow.com'),
      subject: "Thank you for joining #{@event.title}"
    )
  end

  private

  def email_setting
    @event.event_email_setting
  end

  def feedback_url
    return unless self.class.feedback_link_available?(@event)

    base_url = ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
    "#{base_url}/events/#{@event.slug.presence || @event.id}/feedback?ticket=#{@ticket.public_id}"
  end
end
