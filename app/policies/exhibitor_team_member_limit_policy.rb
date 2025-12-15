# app/policies/exhibitor_team_member_limit_policy.rb
class ExhibitorTeamMemberLimitPolicy < ApplicationPolicy
  # View: org owners, organizers, event admins, team members, and vendors (exhibitors)
  def show?
    return false unless user.present? && event.present?

    user.is_org_owner_or_organizer? ||
      user.is_event_admin?(event) ||
      user.is_event_team_member?(event) ||
      user.is_event_vendor?(event)
  end

  # Create/Update/Destroy: only org owners, organizers, and event admins
  def create?
    return false unless user.present? && event.present?

    user.is_org_owner_or_organizer? || user.is_event_admin?(event)
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private

  def event
    record.event || record.try(:event)
  end
end
