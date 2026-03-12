# frozen_string_literal: true

class ExhibitorTeamMemberPaymentVerificationService
  def initialize(payment)
    @payment = payment
  end

  def call
    pending_tickets.each do |ticket|
      ticket.update!(status: :purchased, payment_status: :paid)
    end
  end

  private

  # Find the oldest N pending tickets for this kit's excess team members,
  # where N = the number of extra members covered by this payment.
  #
  # We order by ticket id ASC to match the insertion-order logic
  # used by ExhibitorTeamMemberAttendeeSyncService#excess_member_requiring_payment?,
  # ensuring the earliest excess members get confirmed first.
  def pending_tickets
    kit = @payment.exhibitor_kit

    Ticket
      .joins("INNER JOIN exhibitor_team_members ON exhibitor_team_members.attendee_type = 'Ticket' AND exhibitor_team_members.attendee_id = tickets.id")
      .where(exhibitor_team_members: { exhibitor_kit_id: kit.id })
      .where(status: :pending_payment, payment_status: :pending)
      .order(id: :asc)
      .limit(@payment.extra_member_count)
  end
end
