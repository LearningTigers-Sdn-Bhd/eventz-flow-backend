class SendEventCertificatesJob < ApplicationJob
  queue_as :mailers

  AUDIENCES = %w[all checked_in unsent feedback_submitted rfid_qualified sessions_done sessions_or_feedback].freeze

  # Statuses that mean a certificate is already on its way / delivered, so the
  # ticket should be skipped by the "unsent" audience.
  SENT_STATUSES = %w[queued sending sent delivered].freeze

  def perform(event_id, audience = 'all', excluded_public_ids = [], actor_id = nil, skip_sent = false)
    event = Event.find_by(id: event_id)
    return if event.nil?

    return unless event.certificate_templates.any?(&:ready?)

    recipient_scope(event, audience, excluded_public_ids, skip_sent: skip_sent).find_each do |ticket|
      next unless event.certificate_template_for(ticket)&.ready?

      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'CertificateMailer',
        mailer_action: 'certificate_email',
        args: [ticket],
        related: ticket,
        # An explicit resend (skip_sent off) must bypass the 24h duplicate guard.
        dedupe: skip_sent,
        metadata: {
          source: 'certificate_send',
          event_id: event.id,
          actor_id: actor_id
        }
      )
    end
  end

  # Shared with the controller so the queued count and the actually-sent set
  # are computed from the same rule. Exclusions are keyed on the ticket's
  # public_id (the identifier the panel works with).
  #
  # audience:
  #   all        -> every ticket with an email
  #   checked_in -> only checked-in tickets with an email
  #   unsent     -> tickets with an email that have no in-flight/delivered cert
  #   feedback_submitted -> tickets that answered the event's feedback form
  #   rfid_qualified -> tickets that met every mandatory RFID session and answered the feedback form
  #   sessions_done  -> tickets that met every mandatory RFID session (feedback not required)
  #   sessions_or_feedback -> met every mandatory session OR answered the feedback form
  #
  # skip_sent drops tickets that already have an in-flight/delivered certificate,
  # on top of any audience; leave it off to deliberately resend.
  def self.recipient_scope(event, audience, excluded_public_ids = [], skip_sent: false)
    scope = event.tickets.where.not(attendee_email: [nil, '']).where(waiting_list: false)
    scope = scope.where(checked_in: true) if audience.to_s == 'checked_in'
    scope = scope.where(id: feedback_ticket_ids(event)) if audience.to_s == 'feedback_submitted'
    scope = scope.where(id: Rfid::Attendance.qualified_ticket_ids(event)) if audience.to_s == 'rfid_qualified'
    scope = scope.where(id: Rfid::Attendance.sessions_done_ticket_ids(event)) if audience.to_s == 'sessions_done'
    scope = scope.where(id: sessions_or_feedback_ticket_ids(event)) if audience.to_s == 'sessions_or_feedback'
    scope = scope.where.not(public_id: excluded_public_ids) if excluded_public_ids.present?
    scope = scope.where.not(id: already_sent_ticket_ids(event)) if skip_sent || audience.to_s == 'unsent'
    scope
  end

  # Ticket ids in this event that already have a certificate delivery in a
  # non-failed state. Used to power the "unsent" audience.
  def self.already_sent_ticket_ids(event)
    EmailDelivery
      .where(related_type: 'Ticket', mailer_action: 'certificate_email', status: SENT_STATUSES)
      .where(related_id: event.tickets.select(:id))
      .distinct
      .pluck(:related_id)
  end

  def self.sessions_or_feedback_ticket_ids(event)
    (Rfid::Attendance.sessions_done_ticket_ids(event) + feedback_ticket_ids(event).pluck(:ticket_id)).uniq
  end

  def self.feedback_ticket_ids(event)
    FeedbackResponse.joins(:feedback_form).where(feedback_forms: { event_id: event.id }).select(:ticket_id)
  end

  # Feedback-gated certificates: fired right after an attendee submits the
  # form, when the organizer switched on "require feedback".
  def self.deliver_after_feedback(ticket)
    template = ticket.event.certificate_template_for(ticket)
    return unless template&.ready? && template.require_feedback && ticket.attendee_email.present?
    # Events with mandatory sessions only auto-send to guests who also met them;
    # anyone else is sent later by the organizer.
    return unless Rfid::Attendance.new(ticket.event).qualified?(ticket)

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'CertificateMailer',
      mailer_action: 'certificate_email',
      args: [ticket],
      related: ticket,
      dedupe: true,
      metadata: { source: 'certificate_after_feedback', event_id: ticket.event_id }
    )
  end

  private

  def recipient_scope(event, audience, excluded_public_ids, skip_sent: false)
    self.class.recipient_scope(event, audience, excluded_public_ids, skip_sent: skip_sent)
  end
end
