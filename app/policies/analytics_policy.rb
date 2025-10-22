# app/policies/analytics_policy.rb
class AnalyticsPolicy < ApplicationPolicy
  # Global analytics access - only org owners and managers
  def index?
    user&.is_org_owner? || user&.is_manager?
  end

  # Scope for global analytics - tickets across all events user has access to
  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Get all events the user has access to
      accessible_event_ids = user.event_assignments.pluck(:event_id)

      # If user is org owner or manager, they can see all tickets
      if user.is_org_owner? || user.is_manager?
        return scope.all
      end

      # Otherwise, only tickets from events they're assigned to
      scope.where(event_id: accessible_event_ids)
    end
  end
end
