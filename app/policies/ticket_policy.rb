class TicketPolicy < ApplicationPolicy
  # Convenience method for delegating to the parent resource policy
  def event_policy
    # This assumes the record (a Ticket instance) always has an event association.
    # It also handles nil records safely (e.g., if record is a collection/scope)
    return nil if record.respond_to?(:first) && record.first.nil?

    # We delegate to the EventPolicy using the Ticket's associated Event.
    Pundit.policy(user, record.event)
  rescue NoMethodError
    # Handle cases where record.event is not accessible (e.g., index? being called with a scope)
    nil
  end

  # All staff can index tickets for their managed/staffed event.
  def index?
    true
  end

  # Only organizers/owners can create tickets. Delegates to EventPolicy#update?,
  # which includes necessary status checks (paid?/waived?).
  def create?
    # If the event_policy cannot be initialized (e.g., no event is associated yet), fail safe.
    return false unless record.is_a?(Ticket)
    return false unless record.event.present?
    user.is_event_admin?(record.event)
  end

  # Staff can view any single ticket for their event.
  def show?
    user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  def check_in?
    user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  # Unscan is restricted to org_owner only
  def unscan?
    return false if user.blank? || record.blank?
    user.is_org_owner?
  end

  # Check-in (update status) is typically allowed for all event staff (Admins/Team Members/Organizers).
  def update?
    return false if user.blank? || record.blank?

    # 1. Organization-level permissions (can update ANY ticket)
    return true if user.is_org_owner? || user.is_organizer?

    # 2. Event-level permissions (can only update tickets for their assigned event)
    user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  # Deletion/Refunds are usually restricted to Organizers/Owners.
  def destroy?
    return false if user.blank? || record.blank?

    # 1. Organization-level permissions (can delete ANY ticket)
    return true if user.is_org_owner? || user.is_organizer?

    # 2. Event-level permissions (can only delete tickets for their assigned event)
    user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  # Force delete requires organizer/admin authorization (same as destroy)
  def force_delete?
    destroy?
  end

  # Restore requires organizer/admin authorization (same as destroy)
  def restore?
    destroy?
  end

  # =========================================================================
  # Scope: Correctly filters tickets based on authorized events.
  # This refactoring is the critical fix for the PG::UndefinedColumn error.
  # =========================================================================

  class Scope < Scope
    def resolve
      # 1. Get the scope of events the user is authorized to view (EventPolicy::Scope).
      authorized_events_scope = Pundit.policy_scope(user, Event)

      # 2. Get the IDs of TicketTypes that belong to authorized events
      authorized_ticket_type_ids = TicketType.where(event: authorized_events_scope).select(:id)

      # 3. Get the IDs of GLOBAL TicketTypes (event_id is NULL)
      global_ticket_type_ids = TicketType.where(event_id: nil).select(:id)

      # 4. Combine both: authorized event ticket types + global ticket types
      all_allowed_ticket_type_ids = authorized_ticket_type_ids.or(global_ticket_type_ids)

      # 5. Filter tickets to only include those with allowed ticket types
      scope.where(ticket_type_id: all_allowed_ticket_type_ids)
    end
  end
end
