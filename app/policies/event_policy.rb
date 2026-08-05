# app/policies/event_policy.rb
class EventPolicy < ApplicationPolicy
  # NOTE: User model methods (is_event_admin?, is_event_team_member?, is_org_owner?, is_organizer?) are assumed to exist.

  # ============================================================
  # Basic CRUD Permissions
  # ============================================================

  def index?
    user.present?
  end

  # Only Org Owner or Organizer can create events
  def create?
    user&.is_org_owner? || user&.is_organizer?
  end

  # Can view if: event is published AND visible OR user is staff/management
  def show?
    return false if record.blank?

    # 1. Is the event public (both published and visible)?
    return true if record.published && record.visibility

    # 2. Is the user staff/management? (can view even if not visible)
    user.present? && (
      user.is_org_owner? ||
      user.is_organizer? ||
      user.is_event_admin?(record) ||
      user.is_event_team_member?(record) ||
      user.is_event_vendor?(record) ||
      user.exhibition_contractor_for?(record) ||
      user.is_business_host?(record)
    )
  end

  # Can update if:
  # - Org owner or Organizer (Org-level permission)
  # - User is Event Admin or Team Member (Event-level staff permission)
  def update?
    return false if user.blank?

    # 1. Organization-level Management
    return true if user.is_org_owner? || user.is_organizer?

    # 2. Event-level Staff
    # Allows both Admin and Team Member to update their assigned event.
    return true if user.is_event_admin?(record) || user.is_event_team_member?(record)

    false
  end

  # Destroy follows same logic as update (Permission to delete often mirrors update)
  def destroy?
    update?
  end

  # Force delete requires organizer/admin authorization (same as destroy)
  def force_delete?
    destroy?
  end

  # Restore requires organizer/admin authorization (same as destroy)
  def restore?
    destroy?
  end

  def business_matching_events?
    return false unless record.use_business_matching

    # Allow if user is staff/organizer
    return true if user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record) || user.is_event_team_member?(record)

    # Allow if user is a business host
    return true if user.is_business_host?(record)

    false
  end

  # ============================================================
  # Analytics permissions
  # ============================================================

  # Analytics access: Only event staff/organizers, not general public
  def analytics?
    return false if user.blank? || record.blank?

    # Only allow org owners, organizers, and event staff
    user.is_org_owner? ||
    user.is_organizer? ||
    user.is_event_admin?(record) ||
    user.is_event_team_member?(record)
  end

  # ============================================================
  # Ticket creation
  # ============================================================

  # Organizers or Event Admins can create tickets for their events
  def create_ticket?
    return false if user.blank? || record.blank?
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record)
  end

  def show_exhibitor_kits?
    return false unless record.use_exhibitor_kit? # Only if feature is enabled

    # Org owner, Organizer, Event Admin (for this event), or
    # Exhibition Contractor assigned to this event, or
    # Exhibitor whose kit it is.
    user.is_org_owner? ||
    user.is_organizer? ||
    user.is_event_admin?(record) ||
    user.exhibition_contractor_for?(record) ||
    user.is_event_vendor?(record)
  end

  def manage_business_hosts?
    return false if user.blank? || record.blank?
    user.is_org_owner? || user.is_event_admin?(record)
  end

  # Only Org Owner, Organizer, or Event Admin may curate the offering/interest
  # tag list that business hosts pick from. Business hosts may only select
  # from this list, never create their own tags.
  def manage_business_matching_tags?
    return false if user.blank? || record.blank?
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record)
  end

  # ============================================================
  # Scope for Index (GET /v1/events)
  # ============================================================

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Unwrap PunditUserContext if present
      api_key = user.respond_to?(:api_key) ? user.api_key : nil
      actual_user = user.respond_to?(:user) ? user.user : user

      # API key scoped to a specific event: restrict to that event only
      return scope.where(id: api_key.event_id) if api_key&.event_id.present?

      # Org Owner: See ALL events regardless of status and visibility
      return scope.all if actual_user.is_org_owner?

      # For vendors: See only events they are assigned to (as event_vendor)
      if actual_user.vendor?
        vendor_event_ids = actual_user.event_vendor_assignments.pluck(:event_id)
        return scope.where(id: vendor_event_ids, visibility: true).distinct
      end

      # For exhibitors: See events they are business hosts for
      if actual_user.exhibitor?
        host_event_ids = actual_user.business_host_assignments.pluck(:event_id)
        return scope.where(id: host_event_ids, visibility: true).distinct
      end

      # For exhibition contractors: See only events they are assigned to
      if actual_user.exhibition_contractor?
        return scope.none unless actual_user.exhibition_contractor_profile.present?

        assigned_event_ids = actual_user.exhibition_contractor_profile.event_exhibition_contractors.pluck(:event_id)
        return scope.where(id: assigned_event_ids, visibility: true).distinct
      end

      # Organizer/Member: See only events they are assigned to
      assigned_event_ids = actual_user.event_assignments.pluck(:event_id)

      scope.where(id: assigned_event_ids, visibility: true)
           .distinct
    end
  end
end
