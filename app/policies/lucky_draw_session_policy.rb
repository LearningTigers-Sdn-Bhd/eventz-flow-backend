class LuckyDrawSessionPolicy < ApplicationPolicy
  # show? - event admins, org admins, and exhibitors running the draw at their own event
  def show?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level permissions
    return true if user.is_event_admin?(record.event)

    # Exhibitors may view/run the draw for their own event, using their leads
    user.exhibitor? && user.is_event_vendor?(record.event)
  end

  # create? - same as show?: event admins, org admins, and exhibitors managing their own event's draw
  def create?
    show?
  end

  # update? - same as show?
  def update?
    show?
  end

  # destroy? - same as show?
  def destroy?
    show?
  end

  # background_manager? - same as show?
  def background_manager?
    show?
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner? || user.is_organizer?
        scope.all
      else
        # Sessions for events where user is admin, or an exhibitor at that event
        admin_event_ids = user.event_assignments.where(role: :event_admin).select(:event_id)
        vendor_event_ids = user.exhibitor? ? user.event_vendor_assignments.select(:event_id) : EventVendor.none.select(:event_id)
        scope.joins(:event).where(events: { id: admin_event_ids }).or(
          scope.joins(:event).where(events: { id: vendor_event_ids })
        )
      end
    end
  end
end
