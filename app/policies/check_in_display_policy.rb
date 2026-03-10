class CheckInDisplayPolicy < ApplicationPolicy
  def show?
    user_can_manage_event?
  end

  def update?
    user_can_manage_event?
  end

  private

  def user_can_manage_event?
    return false if user.blank?

    event = record.event || record.association(:event).target
    return false if event.blank?

    user.is_org_owner? ||
      user.is_organizer? ||
      user.is_event_admin?(event) ||
      user.is_event_team_member?(event)
  end
end
