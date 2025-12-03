class EventPrintingServicePriceTierPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || user.exhibition_contractor? || user.is_event_staff?(record.event_printing_service.event)
  end

  def show?
    user.org_owner? || user.organizer? || user.exhibition_contractor? || user.is_event_staff?(record.event_printing_service.event)
  end

  def create?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event_printing_service.event)
  end

  def update?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event_printing_service.event)
  end

  def destroy?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event_printing_service.event)
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor?
        # Only show price tiers for events the contractor is assigned to
        scope.joins(event_printing_service: { event: :event_exhibition_contractors })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_event_staff? # Assuming 'is_event_staff?' takes an event object. This needs to be refined.
        scope.joins(event_printing_service: :event).where(event: user.assigned_events)
      else
        scope.none
      end
    end
  end
end
