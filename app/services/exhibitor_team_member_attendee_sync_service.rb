# frozen_string_literal: true

class ExhibitorTeamMemberAttendeeSyncService
  EXHIBITOR_TICKET_TYPE_NAME = 'Exhibitor'
  TICKET_TYPE_QUANTITY = 99_999

  def initialize(team_member)
    @team_member = team_member
  end

  def call
    return unless event&.use_ticket?

    upgraded_reused_ticket = false
    ticket = if @team_member.attendee.is_a?(Ticket)
               update_ticket(@team_member.attendee)
             elsif (shared_ticket = ExhibitorTeamMemberTicketReconciliationService.shared_ticket(@team_member))
               update_ticket(shared_ticket)
             elsif (upgraded_reused_ticket = reusable_conference_ticket_before_upgrade?) || (reusable_ticket = reusable_borneo_exhibitor_ticket)
               reusable_ticket ||= reusable_borneo_exhibitor_ticket
               update_ticket(reusable_ticket)
             else
               create_ticket
             end

    link_ticket(ticket)
    if upgraded_reused_ticket
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket.reload],
        related: ticket
      )
    end
  end

  private

  def create_ticket
    status, payment_status = desired_ticket_state

    Ticket.create!(
      event: event,
      ticket_type: exhibitor_ticket_type,
      attendee_name: @team_member.full_name,
      attendee_email: @team_member.email,
      attendee_phone: @team_member.phone,
      role: EXHIBITOR_TICKET_TYPE_NAME,
      status: status,
      payment_status: payment_status,
      custom_fields_data: ticket_custom_fields
    )
  end

  def update_ticket(ticket)
    status, payment_status = desired_ticket_state(ticket)
    ticket_type = desired_ticket_type(ticket)

    ticket.update!(
      ticket_type: ticket_type,
      attendee_name: @team_member.full_name,
      attendee_email: @team_member.email,
      attendee_phone: @team_member.phone,
      status: status,
      payment_status: payment_status,
      custom_fields_data: merged_custom_fields(ticket)
    )

    ticket
  end

  def link_ticket(ticket)
    return if @team_member.attendee == ticket

    @team_member.update_column(:attendee_type, ticket.class.name)
    @team_member.update_column(:attendee_id, ticket.id)
  end

  def merged_custom_fields(ticket)
    (ticket&.custom_fields_data.to_h || {}).merge(company_custom_field)
  end

  def ticket_custom_fields
    company_custom_field
  end

  def company_custom_field
    company_name = @team_member.exhibitor_kit.company_name.to_s.strip
    return {} if company_name.blank?

    { 'company' => company_name }
  end

  def exhibitor_ticket_type
    event.ticket_types.find_or_create_by!(name: EXHIBITOR_TICKET_TYPE_NAME) do |ticket_type|
      ticket_type.price = 0
      ticket_type.quantity = TICKET_TYPE_QUANTITY
      ticket_type.max_per_order = TICKET_TYPE_QUANTITY
      ticket_type.status = :published
      ticket_type.hidden = true
    end
  end

  def reusable_borneo_exhibitor_ticket
    BorneoExpoTicketUpgradeService.call(
      event: event,
      attendee_email: @team_member.email,
      target_category: 'exhibitor'
    )
  end

  def reusable_conference_ticket_before_upgrade?
    ticket = matching_event_ticket
    ticket.present? && !borneo_combined_ticket_type?(ticket.ticket_type) && conference_like_ticket_type?(ticket.ticket_type)
  end

  def matching_event_ticket
    normalized_email = @team_member.email.to_s.strip.downcase
    return if normalized_email.blank?

    event.tickets
         .where(attendee_email_norm: normalized_email)
         .where.not(status: %i[canceled refunded])
         .includes(:ticket_type)
         .order(created_at: :desc)
         .first
  end

  def desired_ticket_type(ticket)
    return ticket.ticket_type if borneo_combined_ticket_type?(ticket.ticket_type)

    exhibitor_ticket_type
  end

  def should_send_upgrade_email?(ticket)
    !borneo_combined_ticket_type?(ticket.ticket_type) && conference_like_ticket_type?(ticket.ticket_type)
  end

  def conference_like_ticket_type?(ticket_type)
    name = ticket_type&.name.to_s.downcase
    name.include?('conference') || name.include?('delegate')
  end

  def borneo_combined_ticket_type?(ticket_type)
    unless event.slug.to_s.strip.downcase.start_with?(BorneoExpoTicketUpgradeService::BORNEO_EVENT_SLUG_PREFIX)
      return false
    end

    name = ticket_type&.name.to_s.downcase
    name.include?('exhibitor') && (name.include?('conference') || name.include?('delegate'))
  end

  def desired_ticket_state(ticket = nil)
    return %i[pending_payment pending] unless ExhibitorTeamMemberTicketReconciliationService.entitled?(@team_member)
    return %i[purchased paid] if ticket&.purchased? && ticket&.paid?

    %i[purchased paid]
  end

  def event
    @team_member.exhibitor_kit.event
  end
end
