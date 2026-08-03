# frozen_string_literal: true

class ExhibitorTeamMemberTicketReconciliationService
  def self.entitled?(team_member, excluding: nil)
    matching_members(team_member, excluding: excluding).any? { |member| member_entitled?(member) }
  end

  def self.shared?(team_member, excluding: nil)
    matching_members(team_member, excluding: excluding).exists?
  end

  def self.shared_ticket(team_member)
    matching_members(team_member, excluding: team_member).filter_map(&:attendee).find { |attendee| attendee.is_a?(Ticket) }
  end

  def self.member_entitled?(team_member)
    kit = team_member.exhibitor_kit
    return false unless kit.paid?
    return true unless kit.has_team_member_limit? && kit.extra_team_member_fee.to_f.positive?

    position = kit.exhibitor_team_members.order(:id).where('id <= ?', team_member.id).count - 1
    position < kit.team_member_limit + kit.paid_extra_member_count
  end

  def self.matching_members(team_member, excluding: nil)
    normalized_email = team_member.email.to_s.strip.downcase
    return ExhibitorTeamMember.none if normalized_email.blank?

    team_member.exhibitor_kit.event_vendor.exhibitor_team_members
      .where('LOWER(TRIM(exhibitor_team_members.email)) = ?', normalized_email)
      .where.not(id: excluding&.id)
  end
  private_class_method :matching_members

  def initialize(exhibitor_kit, verified_paid_slot_count: nil)
    @exhibitor_kit = exhibitor_kit
    @verified_paid_slot_count = verified_paid_slot_count
  end

  def call
    return unless @exhibitor_kit.event.use_ticket?

    @exhibitor_kit.exhibitor_team_members.order(:id).each_with_index do |team_member, index|
      ticket = team_member.attendee
      next unless ticket.is_a?(Ticket)

      desired_status, desired_payment_status = desired_ticket_state_for(team_member, index)
      next if ticket.status == desired_status && ticket.payment_status == desired_payment_status

      ticket.update!(status: desired_status, payment_status: desired_payment_status)
    end
  end

  private

  def desired_ticket_state_for(team_member, index)
    return %i[purchased paid] if self.class.entitled?(team_member)
    return %i[purchased paid] if current_kit_member_entitled?(index)

    %i[pending_payment pending]
  end

  def current_kit_member_entitled?(index)
    return false unless @exhibitor_kit.paid?
    return true unless @exhibitor_kit.has_team_member_limit?
    return true unless @exhibitor_kit.extra_team_member_fee.to_f.positive?

    index < @exhibitor_kit.team_member_limit + verified_paid_slot_count
  end

  def verified_paid_slot_count
    @verified_paid_slot_count ||= @exhibitor_kit.exhibitor_team_member_payments.verified.sum(:extra_member_count)
  end
end
