# Booth plans inherit permissions from their parent event, same as EventLocationPolicy:
# anyone who can view the event can view its booth plans, anyone who can update the
# event (org_owner/organizer) can manage them.
class BoothPlanPolicy < ApplicationPolicy
  def index?
    return false if record.blank?

    event = record.is_a?(Event) ? record : record.event
    EventPolicy.new(user, event).show?
  end

  def show?
    return false if record.blank?

    EventPolicy.new(user, record.event).show?
  end

  def create?
    return false if user.blank? || record.blank?

    event = record.is_a?(Event) ? record : record.event
    EventPolicy.new(user, event).update?
  end

  def update?
    return false if user.blank? || record.blank?

    EventPolicy.new(user, record.event).update?
  end

  def destroy?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      viewable_event_ids = EventPolicy::Scope.new(user, Event).resolve.pluck(:id)
      scope.where(event_id: viewable_event_ids)
    end
  end
end
