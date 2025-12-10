class LuckyDrawSessionPolicy < ApplicationPolicy
  # show? - event admins and org admins
  def show?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level permissions
    user.is_event_admin?(record.event)
  end

  # create? - event admins and org admins
  def create?
    show?
  end

  # update? - event admins and org admins
  def update?
    show?
  end

  # destroy? - event admins and org admins
  def destroy?
    show?
  end

  # background_manager? - event admins and org admins (same as update)
  def background_manager?
    update?
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner? || user.is_organizer?
        scope.all
      else
        # Only sessions for events where user is admin
        scope.joins(:event).where(events: { id: user.event_assignments.where(role: :event_admin).select(:event_id) })
      end
    end
  end
end
