# frozen_string_literal: true

class ExhibitorTeamMemberPaymentVerificationService
  def initialize(payment)
    @payment = payment
  end

  def call
    ExhibitorTeamMemberTicketReconciliationService.new(
      @payment.exhibitor_kit,
      verified_paid_slot_count: verified_paid_slot_count
    ).call
  end

  private

  def verified_paid_slot_count
    @payment.exhibitor_kit.exhibitor_team_member_payments
            .verified
            .where.not(id: @payment.id)
            .sum(:extra_member_count) + @payment.extra_member_count
  end
end
