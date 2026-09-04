class EventEmailSetting < ApplicationRecord
  belongs_to :event

  validates :event_id, uniqueness: true

  # Groups every event-scoped mailer action into a toggle an org_owner can
  # switch off. Keys are what's stored in `disabled_categories`. `group` is
  # display-only (ticket/exhibitor/general), matched by the frontend's
  # email-categories.ts.
  #
  # Note: EventReminderMailer#reminder / #group_reminder (the day-of event
  # reminder) has no category here — it's already gated by `Event#reminders_enabled`
  # on the separate "Event Reminder" settings tab, no need for a second toggle.
  CATEGORIES = {
    'ticket_confirmation' => {
      label: 'Ticket Confirmation (paid)',
      group: 'ticket',
      mailers: [%w[TicketMailer confirmation_email], %w[TicketMailer group_confirmation_email]]
    },
    'ticket_payment_pending' => {
      label: 'Unpaid Ticket Notice',
      group: 'ticket',
      mailers: [%w[TicketMailer payment_pending_email], %w[TicketMailer group_payment_pending_email]]
    },
    'payment_pending_reminder' => {
      label: 'Unpaid Payment Reminder',
      group: 'ticket',
      mailers: [%w[EventReminderMailer pending_payment_reminder], %w[EventReminderMailer group_pending_payment_reminder]]
    },
    'voucher_showcase' => {
      label: 'Voucher Showcase Follow-up',
      group: 'ticket',
      mailers: [%w[TicketMailer voucher_showcase_email]]
    },
    'business_matching_invite' => {
      label: 'Business Matching Invite',
      group: 'general',
      mailers: [%w[TicketMailer business_matching_email]]
    },
    'certificate' => {
      label: 'E-Certificate',
      group: 'ticket',
      mailers: [%w[CertificateMailer certificate_email]]
    },
    'ticket_application' => {
      label: 'Ticket Application (RSVP)',
      group: 'ticket',
      mailers: [
        %w[TicketApplicationMailer acknowledgement],
        %w[TicketApplicationMailer rsvp_invitation],
        %w[TicketApplicationMailer rejection]
      ]
    },
    'exhibitor_registration_received' => {
      label: 'Exhibitor Registration Received (unpaid)',
      group: 'exhibitor',
      mailers: [%w[ExhibitorRegistrationMailer registration_received_email]]
    },
    'exhibitor_payment_confirmed' => {
      label: 'Exhibitor Payment Confirmed (paid)',
      group: 'exhibitor',
      mailers: [%w[ExhibitorRegistrationMailer payment_confirmed_email]]
    },
    'exhibitor_welcome' => {
      label: 'Exhibitor Portal Welcome',
      group: 'exhibitor',
      mailers: [%w[PublicExhibitorWelcomeMailer welcome]]
    },
    'exhibitor_access_link' => {
      label: 'Exhibitor Portal Access Link',
      group: 'exhibitor',
      mailers: [%w[PublicExhibitorAccessMailer access_link]]
    },
    'booking' => {
      label: 'Session Booking (Business Matching)',
      group: 'general',
      mailers: %w[
        confirmation_email pending_approval_email approval_email host_confirmation_email
        reschedule_email host_reschedule_email cancellation_email host_cancellation_email
        session_reminder_email host_daily_overview_email
      ].map { |action| ['BookingMailer', action] }
    }
  }.freeze

  # mailer_name/mailer_action pair -> category key, built once from CATEGORIES.
  CATEGORY_BY_MAILER = CATEGORIES.each_with_object({}) do |(key, cfg), memo|
    cfg[:mailers].each { |mailer_name, action| memo[[mailer_name, action]] = key }
  end.freeze

  validate :disabled_categories_are_known

  # Whether AuditedDelivery should actually send this mailer/action. Mailers
  # not in CATEGORIES (e.g. UserMailer password_reset) are never gated here.
  def email_enabled?(mailer_name, mailer_action)
    return false unless emails_enabled

    category = CATEGORY_BY_MAILER[[mailer_name, mailer_action]]
    return true unless category

    disabled_categories.exclude?(category)
  end

  # Ticket-type opt-in for the business_matching_invite category — the
  # category toggle alone gates whether the mailer fires at all, this
  # narrows it further to only the ticket types the organizer picked.
  def business_matching_enabled_for_ticket_type?(ticket_type_id)
    Array(business_matching_ticket_type_ids).map(&:to_i).include?(ticket_type_id.to_i)
  end

  private

  def disabled_categories_are_known
    unknown = Array(disabled_categories) - CATEGORIES.keys
    errors.add(:disabled_categories, "contains unknown categories: #{unknown.join(', ')}") if unknown.present?
  end
end
