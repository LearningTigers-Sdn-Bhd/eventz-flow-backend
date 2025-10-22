# app/policies/event_policy.rb
class EventPolicy < ApplicationPolicy
  # NOTE: User model methods (is_event_admin?, is_event_team_member?, is_org_owner?, is_manager?) are assumed to exist.

  # ============================================================
  # Basic CRUD Permissions
  # ============================================================

  def index?
    user.present?
  end

  # Only Org Owner or Manager can create events
  def create?
    user&.is_org_owner? || user&.is_manager?
  end

  # Can view if: event is published OR user is staff/management
  def show?
    return false if record.blank?

    # 1. Is the event public?
    return true if record.published?

    # 2. Is the user staff/management?
    user.present? && (
      user.is_org_owner? ||
      user.is_manager? ||
      user.is_event_admin?(record) ||
      user.is_event_team_member?(record)
    )
  end

  # Can update if:
  # - Org owner or Manager (Org-level permission)
  # - User is Event Admin or Team Member (Event-level staff permission)
  def update?
    return false if user.blank?

    # 1. Organization-level Management
    return true if user.is_org_owner? || user.is_manager?

    # 2. Event-level Staff
    # Allows both Admin and Team Member to update their assigned event.
    return true if user.is_event_admin?(record) || user.is_event_team_member?(record)

    false
  end

  # Destroy follows same logic as update (Permission to delete often mirrors update)
  def destroy?
    update?
  end

  # ============================================================
  # Analytics permissions
  # ============================================================

  # Analytics access: Only event staff/managers, not general public
  def analytics?
    return false if user.blank? || record.blank?

    # Only allow org owners, managers, and event staff
    user.is_org_owner? ||
    user.is_manager? ||
    user.is_event_admin?(record) ||
    user.is_event_team_member?(record)
  end

  # ============================================================
  # Ticket creation
  # ============================================================

  # Managers or Event Admins can create tickets for their events
  def create_ticket?
    return false if user.blank? || record.blank?
    user.is_org_owner? || user.is_manager? || user.is_event_admin?(record)
  end

  # ============================================================
  # Scope for Index (GET /v1/events)
  # ============================================================

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      assigned_event_ids = user.event_assignments.pluck(:event_id)

      # Show published events OR events the user is staff for
      scope.where(published: true)
           .or(scope.where(id: assigned_event_ids))
           .distinct
    end
  end
end
