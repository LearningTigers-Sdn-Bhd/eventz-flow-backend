# frozen_string_literal: true

class ExhibitorTeamMemberAttendeeSyncService
  EXHIBITOR_TICKET_TYPE_NAME = 'Exhibitor'.freeze
  TICKET_TYPE_QUANTITY = 99_999

  def initialize(team_member)
    @team_member = team_member
  end

  def call
    return unless event&.use_ticket?

    ticket = @team_member.attendee.is_a?(Ticket) ? update_ticket(@team_member.attendee) : create_ticket
    link_ticket(ticket)
  end

  private

  def create_ticket
    if excess_member_requiring_payment?
      Ticket.create!(
        event: event,
        ticket_type: exhibitor_ticket_type,
        attendee_name: @team_member.full_name,
        attendee_email: @team_member.email,
        attendee_phone: @team_member.phone,
        role: EXHIBITOR_TICKET_TYPE_NAME,
        status: :pending_payment,
        payment_status: :pending
      )
    else
      Ticket.create!(
        event: event,
        ticket_type: exhibitor_ticket_type,
        attendee_name: @team_member.full_name,
        attendee_email: @team_member.email,
        attendee_phone: @team_member.phone,
        role: EXHIBITOR_TICKET_TYPE_NAME,
        status: :purchased,
        payment_status: :paid
      )
    end
  end

  def update_ticket(ticket)
    # If the ticket is already confirmed (purchased + paid), preserve its payment status.
    # Only the payment verification flow should ever upgrade a pending ticket to paid,
    # so we must never downgrade a paid ticket back to pending on a simple info update.
    if ticket.purchased? && ticket.paid?
      ticket.update!(
        ticket_type: exhibitor_ticket_type,
        attendee_name: @team_member.full_name,
        attendee_email: @team_member.email,
        attendee_phone: @team_member.phone,
        role: EXHIBITOR_TICKET_TYPE_NAME,
        status: :purchased,
        payment_status: :paid
      )
    elsif excess_member_requiring_payment?
      ticket.update!(
        ticket_type: exhibitor_ticket_type,
        attendee_name: @team_member.full_name,
        attendee_email: @team_member.email,
        attendee_phone: @team_member.phone,
        role: EXHIBITOR_TICKET_TYPE_NAME,
        status: :pending_payment,
        payment_status: :pending
      )
    else
      ticket.update!(
        ticket_type: exhibitor_ticket_type,
        attendee_name: @team_member.full_name,
        attendee_email: @team_member.email,
        attendee_phone: @team_member.phone,
        role: EXHIBITOR_TICKET_TYPE_NAME,
        status: :purchased,
        payment_status: :paid
      )
    end

    ticket
  end

  def link_ticket(ticket)
    return if @team_member.attendee == ticket

    @team_member.update_column(:attendee_type, ticket.class.name)
    @team_member.update_column(:attendee_id, ticket.id)
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

  # Returns true if this team member sits in an excess position (beyond the free limit)
  # AND the event is configured to charge an extra fee for those members.
  #
  # Position is determined by ordering all team members for this kit by their database id
  # (ascending), which preserves insertion order. The first `team_member_limit` members
  # (0-indexed positions 0 … limit-1) are free; every member at position >= limit is excess.
  def excess_member_requiring_payment?
    kit = @team_member.exhibitor_kit

    # No limit configured — all members are free
    return false unless kit.has_team_member_limit?

    # Limit is configured but no extra fee — excess members are still free
    return false unless kit.extra_team_member_fee.to_f > 0

    # Determine the 0-based position of this member among all members for this kit
    all_member_ids = kit.exhibitor_team_members.order(:id).pluck(:id)
    position = all_member_ids.index(@team_member.id)

    # Guard against the member not being found (should not happen after commit)
    return false if position.nil?

    position >= kit.team_member_limit
  end

  def event
    @team_member.exhibitor_kit.event
  end
end
