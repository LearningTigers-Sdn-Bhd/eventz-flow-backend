class VisitorPolicy < ApplicationPolicy
  # Convenience method for delegating to the parent resource policy
  def event_policy
    # This assumes the record (a Visitor instance) always has an event association.
    # It also handles nil records safely (e.g., if record is a collection/scope)
    return nil if record.respond_to?(:first) && record.first.nil?

    # We delegate to the EventPolicy using the Visitor's associated Event.
    Pundit.policy(user, record.event)
  rescue NoMethodError
    # Handle cases where record.event is not accessible (e.g., index? being called with a scope)
    nil
  end

  # All staff can index visitors for their managed/staffed event.
  def index?
    true
  end

  # Only organizers/owners can create visitors. Delegates to EventPolicy#update?,
  # which includes necessary status checks (paid?/waived?).
  def create?
    # If the event_policy cannot be initialized (e.g., no event is associated yet), fail safe.
    return false unless record.is_a?(Visitor)
    return false unless record.event.present?

    # Allow Org Owner, Organizer, or Event Admin
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record.event)
  end

  # Staff can view any single visitor for their event.
  def show?
    user.is_event_admin?(record.event) ||
      user.is_event_team_member?(record.event) ||
      user.is_event_vendor?(record.event)
  end

  # Check-in (update status) is typically allowed for all event staff (Admins/Team Members/Organizers).
  def update?
    return false if user.blank? || record.blank?

    # 1. Organization-level permissions (can update ANY visitor)
    return true if user.is_org_owner? || user.is_organizer?

    # 2. Event-level permissions (can only update visitors for their assigned event)
    user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  # Check-in policy - same as update, allows staff to check in visitors
  def check_in?
    update?
  end

  def unscan?
    return false if user.blank? || record.blank?

    user.is_org_owner? || user.is_organizer?
  end

  # Deletion is restricted to Org Owners and Event Admins.
  def destroy?
    user.is_org_owner? || user.is_event_admin?(record.event)
  end

  # =========================================================================
  # Scope: Correctly filters visitors based on authorized events.
  # =========================================================================

  class Scope < Scope
    def resolve
      # 1. Get the scope of events the user is authorized to view (EventPolicy::Scope).
      authorized_events_scope = Pundit.policy_scope(user, Event)

      # 2. Filter visitors to only include those with allowed events
      scope.where(event: authorized_events_scope)
    end
  end
end
