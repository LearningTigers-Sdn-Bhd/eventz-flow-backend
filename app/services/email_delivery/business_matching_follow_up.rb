# Chains TicketMailer#business_matching_email right after a ticket
# confirmation email goes out, same pattern as VoucherFollowUp. Hooked once
# from AuditedDelivery.deliver_later so every existing confirmation path
# (free registration, paid webhook, resend, exhibitor sync, Borneo upgrade,
# and the Ticket#send_confirmation_email model callback) picks it up
# automatically.
module EmailDelivery::BusinessMatchingFollowUp
  CHAINED_ACTIONS = %w[confirmation_email group_confirmation_email].freeze

  def self.enqueue_after(mailer_name, mailer_action, args)
    return unless mailer_name == 'TicketMailer' && CHAINED_ACTIONS.include?(mailer_action)

    ticket = args.first
    return unless ticket.is_a?(Ticket) && ticket.attendee_email.present?

    event = ticket.event
    return unless event.use_business_matching?

    setting = event.event_email_setting
    return unless setting&.business_matching_enabled_for_ticket_type?(ticket.ticket_type_id)

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'TicketMailer',
      mailer_action: 'business_matching_email',
      args: [ticket],
      related: ticket,
      dedupe: true
    )
  end
end
