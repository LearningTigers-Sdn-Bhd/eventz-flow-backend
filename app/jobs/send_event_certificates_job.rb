class SendEventCertificatesJob < ApplicationJob
  queue_as :mailers

  AUDIENCES = %w[all checked_in unsent].freeze

  # Statuses that mean a certificate is already on its way / delivered, so the
  # ticket should be skipped by the "unsent" audience.
  SENT_STATUSES = %w[queued sending sent delivered].freeze

  def perform(event_id, audience = 'all', excluded_public_ids = [], actor_id = nil)
    event = Event.find_by(id: event_id)
    return if event.nil?

    template = event.certificate_template
    return unless template&.ready?

    recipient_scope(event, audience, excluded_public_ids).find_each do |ticket|
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'CertificateMailer',
        mailer_action: 'certificate_email',
        args: [ticket],
        related: ticket,
        dedupe: true,
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
  def self.recipient_scope(event, audience, excluded_public_ids = [])
    scope = event.tickets.where.not(attendee_email: [nil, '']).where(waiting_list: false)
    scope = scope.where(checked_in: true) if audience.to_s == 'checked_in'
    scope = scope.where.not(public_id: excluded_public_ids) if excluded_public_ids.present?
    scope = scope.where.not(id: already_sent_ticket_ids(event)) if audience.to_s == 'unsent'
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

  private

  def recipient_scope(event, audience, excluded_public_ids)
    self.class.recipient_scope(event, audience, excluded_public_ids)
  end
end
