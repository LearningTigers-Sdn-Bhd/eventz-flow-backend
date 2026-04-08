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
      custom_fields_data: merged_custom_fields
    )
  end

  def update_ticket(ticket)
    status, payment_status = desired_ticket_state(ticket)

    ticket.update!(
      ticket_type: exhibitor_ticket_type,
      attendee_name: @team_member.full_name,
      attendee_email: @team_member.email,
      attendee_phone: @team_member.phone,
      role: EXHIBITOR_TICKET_TYPE_NAME,
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

  def merged_custom_fields(ticket = nil)
    existing_custom_fields = ticket&.custom_fields_data.to_h
    existing_custom_fields.merge('conferences_included' => conferences_included)
  end

  def conferences_included
    @team_member.exhibitor_kit.exhibitor_booth_price&.conferences_included || false
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

  def desired_ticket_state(ticket = nil)
    return %i[pending_payment pending] unless @team_member.exhibitor_kit.paid?
    return %i[purchased paid] if ticket&.purchased? && ticket&.paid?
    return %i[pending_payment pending] if excess_member_requiring_payment?

    %i[purchased paid]
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
