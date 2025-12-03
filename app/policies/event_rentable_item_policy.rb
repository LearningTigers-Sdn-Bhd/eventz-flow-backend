class EventRentableItemPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event) || user.exhibition_contractor_for?(record.event)
  end

  def show?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event) || user.exhibition_contractor_for?(record.event)
  end

  def create?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  def update?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  def destroy?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor?
        # Only show rentable items for events the contractor is assigned to
        scope.joins(event: :event_exhibition_contractors)
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_event_staff? # Assuming 'is_event_staff?' takes an event object. This needs to be refined.
        # This will need to be scoped by event assignment
        scope.joins(:event).where(event: user.assigned_events)
      else
        scope.none
      end
    end
  end
end
