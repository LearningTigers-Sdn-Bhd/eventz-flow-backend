# Chains TicketMailer#voucher_showcase_email right after a ticket
# confirmation email goes out. Hooked once from AuditedDelivery.deliver_later
# instead of every confirmation_email call site (free registration, paid
# webhook, resend, exhibitor sync, Borneo upgrade) — one place to keep in
# sync if the chain ever changes.
module EmailDelivery::VoucherFollowUp
  CHAINED_ACTIONS = %w[confirmation_email group_confirmation_email].freeze

  def self.enqueue_after(mailer_name, mailer_action, args)
    return unless mailer_name == 'TicketMailer' && CHAINED_ACTIONS.include?(mailer_action)

    ticket = args.first
    return unless ticket.is_a?(Ticket) && ticket.attendee_email.present?

    event = ticket.event
    return unless event.use_voucher? && event.vouchers.active.exists?

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'TicketMailer',
      mailer_action: 'voucher_showcase_email',
      args: [ticket],
      related: ticket,
      dedupe: true
    )
  end
end
