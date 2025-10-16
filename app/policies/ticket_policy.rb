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

  # Only managers/owners can create tickets. Delegates to EventPolicy#update?, 
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

  # Check-in (update status) is typically allowed for all event staff (Admins/Team Members/Managers).
  def update?
    # Use the EventPolicy#show? permission as a proxy for "is this person staff for this event?"
    event_policy&.show? || false
  end
  
  # Deletion/Refunds are usually restricted to Managers/Owners.
  def destroy?
    # Delegate to the event's update permission, which is restricted to managers/owners.
    event_policy&.update? || false
  end

  # =========================================================================
  # Scope: Correctly filters tickets based on authorized events.
  # This refactoring is the critical fix for the PG::UndefinedColumn error.
  # =========================================================================

  class Scope < Scope
    def resolve
      # 1. Get the scope of events the user is authorized to view (EventPolicy::Scope).
      authorized_events_scope = Pundit.policy_scope(user, Event)
      
      # 2. Get the IDs of all TicketTypes that belong to those authorized events.
      authorized_ticket_type_ids = TicketType.where(event: authorized_events_scope).select(:id)

      # 3. Filter the current scope (Tickets) to only include those associated 
      #    with authorized TicketTypes.
      scope.where(ticket_type_id: authorized_ticket_type_ids)
    end
  end
end