# app/policies/event_location_policy.rb
class EventLocationPolicy < ApplicationPolicy
  # NOTE: Event locations inherit permissions from their parent event.
  # Users who can update an event can also manage its locations.

  # ============================================================
  # Basic CRUD Permissions
  # ============================================================

  def index?
    # Can view locations if they can view the event
    return false if record.blank?
    event = record.is_a?(Event) ? record : record.event
    EventPolicy.new(user, event).show?
  end

  def show?
    # Can view a specific location if they can view the event
    return false if record.blank?
    event = record.event
    EventPolicy.new(user, event).show?
  end

  # Only users who can update the event can create locations
  def create?
    return false if user.blank? || record.blank?
    event = record.is_a?(Event) ? record : record.event
    EventPolicy.new(user, event).update?
  end

  # Only users who can update the event can update locations
  def update?
    return false if user.blank? || record.blank?
    event = record.event
    EventPolicy.new(user, event).update?
  end

  # Only users who can update the event can delete locations
  def destroy?
    update?
  end

  # ============================================================
  # Scope for Index (GET /v1/events/:event_id/event_locations)
  # ============================================================

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Get all events the user can view
      viewable_event_ids = EventPolicy::Scope.new(user, Event).resolve.pluck(:id)

      # Return locations for those events
      scope.where(event_id: viewable_event_ids)
    end
  end
end
