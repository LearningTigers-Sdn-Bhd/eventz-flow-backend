class WishPolicy < ApplicationPolicy
  def index?
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(event)
  end

  def approve?
    index?
  end

  def reject?
    index?
  end

  def destroy?
    user.is_org_owner? || user.is_event_admin?(event)
  end

  class Scope < Scope
    def resolve
      authorized_events_scope = Pundit.policy_scope(user, Event)
      scope.where(event: authorized_events_scope)
    end
  end

  private

  def event
    record.is_a?(Wish) ? record.event : record
  end
end
