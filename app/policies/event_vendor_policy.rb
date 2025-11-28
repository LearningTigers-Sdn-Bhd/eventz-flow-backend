# app/policies/event_vendor_policy.rb
class EventVendorPolicy < ApplicationPolicy
  # Note: user = @current_user, record = the EventVendor instance being acted upon

  class Scope < Scope
    def resolve
      if user.org_owner?
        # Org owners can see all event vendors
        scope.all
      elsif user.organizer?
        # Organizers can see event vendors for events they created
        scope.joins(:event).where(events: { created_by_id: user.id })
      elsif user.vendor?
        # Vendors can only see their own event vendor assignments
        scope.where(vendor_id: user.id)
      else
        # Members and others can't see event vendors
        scope.none
      end
    end
  end

  def index?
    # Anyone can list event vendors if they can view the event
    # (event authorization is handled separately in the controller)
    true
  end

  def show?
    user.org_owner? || user.is_event_admin?(record.event) || record.vendor_id == user.id
  end

  def create?
    # Org_owner and Organizers can create vendors for any event they manage
    user.org_owner? || user.is_organizer? || user.is_event_admin?(record.event)
  end

  def update?
    user.org_owner? ||
    user.is_organizer? ||
    user.is_event_admin?(record.event) ||
    record.vendor_id == user.id ||
    (user.is_exhibition_contractor? && user.exhibition_contractor_for?(record.event))
  end

  def destroy?
    # Only Org_owner, Organizers and event admins can remove vendors from events
    user.org_owner? || user.is_organizer? || user.is_event_admin?(record.event)
  end
end
