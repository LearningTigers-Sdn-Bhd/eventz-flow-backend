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

  def update_ticket(ticket)
    ticket.update!(
      ticket_type: exhibitor_ticket_type,
      attendee_name: @team_member.full_name,
      attendee_email: @team_member.email,
      attendee_phone: @team_member.phone,
      role: EXHIBITOR_TICKET_TYPE_NAME,
      status: :purchased,
      payment_status: :paid
    )
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

  def event
    @team_member.exhibitor_kit.event
  end
end
