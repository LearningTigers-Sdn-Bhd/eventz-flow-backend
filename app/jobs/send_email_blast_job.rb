class SendEmailBlastJob < ApplicationJob
  queue_as :mailers

  def perform(blast_id)
    blast = EmailBlast.find_by(id: blast_id)
    return if blast.nil? || blast.draft?

    blast.recipient_tickets.to_a.each do |ticket|
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'EmailBlastMailer',
        mailer_action: 'blast_email',
        args: [blast, ticket.attendee_email],
        related: blast,
        event: blast.event,
        metadata: { source: 'email_blast', event_id: blast.event_id, email_blast_id: blast.id }
      )
    end
  end
end
