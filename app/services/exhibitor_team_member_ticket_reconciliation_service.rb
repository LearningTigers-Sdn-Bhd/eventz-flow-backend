# frozen_string_literal: true

class ExhibitorTeamMemberTicketReconciliationService
  def initialize(exhibitor_kit, verified_paid_slot_count: nil)
    @exhibitor_kit = exhibitor_kit
    @verified_paid_slot_count = verified_paid_slot_count
  end

  def call
    return unless @exhibitor_kit.event.use_ticket?

    @exhibitor_kit.exhibitor_team_members.order(:id).each_with_index do |team_member, index|
      ticket = team_member.attendee
      next unless ticket.is_a?(Ticket)

      desired_status, desired_payment_status = desired_ticket_state_for(index)
      next if ticket.status == desired_status && ticket.payment_status == desired_payment_status

      ticket.update!(status: desired_status, payment_status: desired_payment_status)
    end
  end

  private

  def desired_ticket_state_for(index)
    return %i[pending_payment pending] unless @exhibitor_kit.paid?
    return %i[purchased paid] unless @exhibitor_kit.has_team_member_limit?
    return %i[purchased paid] unless @exhibitor_kit.extra_team_member_fee.to_f.positive?
    return %i[purchased paid] if index < @exhibitor_kit.team_member_limit

    excess_index = index - @exhibitor_kit.team_member_limit
    if excess_index < verified_paid_slot_count
      %i[purchased paid]
    else
      %i[pending_payment pending]
    end
  end

  def verified_paid_slot_count
    @verified_paid_slot_count ||= @exhibitor_kit.exhibitor_team_member_payments.verified.sum(:extra_member_count)
  end
end
