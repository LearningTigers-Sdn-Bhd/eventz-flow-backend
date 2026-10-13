# The people running the event can see its halls and counts: org owners,
# organizers, and the event's own admins and team members. A public event is
# visible to everyone (EventPolicy#show?), but its crowd history and counter
# links are not, so this does not defer to it. Setting halls up is
# org-owner-only: halls, and linking a hall to a counter, decide whose live
# data an event can read.
class EventHallPolicy < ApplicationPolicy
  STAFF_ROLES = %i[event_admin event_team_member].freeze

  def index?
    show?
  end

  def show?
    return false if user.blank? || record.blank?

    user.is_organizer? || user.is_event_admin?(record.event) || user.is_event_team_member?(record.event)
  end

  def create?
    return false if user.blank? || record.blank?

    user.is_org_owner? && EventPolicy.new(user, record.event).update?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  # Kept as its own name for the call sites that gate the counter link and the
  # venue list; same rule as managing halls.
  def link_counter?
    create?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.is_organizer?

      scope.where(event_id: EventAssignment.where(user_id: user.id, role: STAFF_ROLES).select(:event_id))
    end
  end
end
