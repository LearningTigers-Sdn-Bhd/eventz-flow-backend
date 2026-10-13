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
    return if already_sent_to_address?(ticket)

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'TicketMailer',
      mailer_action: 'voucher_showcase_email',
      args: [ticket],
      related: ticket,
      dedupe: true
    )
  end

  # The showcase email is identical for every ticket, so one address (a family
  # or group sharing an inbox) only needs it once per event. AuditedDelivery's
  # own dedupe is per ticket, which still lets N tickets send N emails.
  def self.already_sent_to_address?(ticket)
    EmailDelivery
      .joins("INNER JOIN tickets ON tickets.id = email_deliveries.related_id AND email_deliveries.related_type = 'Ticket'")
      .where(mailer_name: 'TicketMailer', mailer_action: 'voucher_showcase_email',
             status: EmailDelivery::AuditedDelivery::IN_FLIGHT_STATUSES, tickets: { event_id: ticket.event_id })
      .where('email_deliveries.created_at >= ?', EmailDelivery::AuditedDelivery::DEDUPE_WINDOW.ago)
      .exists?(['lower(email_deliveries.recipient) = ?', ticket.attendee_email.strip.downcase])
  end
  private_class_method :already_sent_to_address?
end
