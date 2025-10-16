# app/policies/event_policy.rb
class EventPolicy < ApplicationPolicy
  # ============================================================
  # Helper methods
  # ============================================================

  def is_event_admin?
    return false if user.blank? || record.blank?
    EventAdmin.exists?(user_id: user.id, event_id: record.id)
  end

  def is_event_team_member?
    return false if user.blank? || record.blank?
    EventTeamMember.exists?(user_id: user.id, event_id: record.id)
  end

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

  # Can view if:
  # - Event is published
  # - User is org owner, manager, admin, or team member
  def show?
    return false if record.blank?
    record.published? ||
      user&.is_org_owner? ||
      user&.is_manager? ||
      is_event_admin? ||
      is_event_team_member?
  end

  # Can update if:
  # - Org owner
  # - Manager or event admin AND event is paid or waived
  def update?
    return false if record.blank?
    user&.is_org_owner? ||
      ((user&.is_manager? || is_event_admin?) && (record.respond_to?(:paid?) && (record.paid? || record.try(:waived?))))
  end

  # Destroy follows same logic as update
  def destroy?
    update?
  end

  # ============================================================
  # Ticket creation (fixes rspec failure)
  # ============================================================

  # Managers or Event Admins can create tickets for their events
  def create_ticket?
    return false if user.blank? || record.blank?
    user.is_org_owner? || user.is_manager? || is_event_admin?
  end

  # ============================================================
  # Scope for Index (GET /v1/events)
  # ============================================================

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      admin_event_ids = EventAdmin.where(user_id: user.id).pluck(:event_id)
      team_event_ids  = EventTeamMember.where(user_id: user.id).pluck(:event_id)
      assigned_ids    = (admin_event_ids + team_event_ids).uniq

      scope.where(published: true).or(scope.where(id: assigned_ids)).distinct
    end
  end
end
