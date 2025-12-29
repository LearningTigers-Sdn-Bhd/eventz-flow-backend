class EventPrintingServicePolicy < ApplicationPolicy
  def index?
    user.org_owner? || 
    user.organizer? || 
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) || 
    (record&.event && user.is_event_staff?(record.event)) ||
    user.vendor?  # Allow vendors to browse printing services
  end

  def show?
    user.org_owner? || 
    user.organizer? || 
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) || 
    (record&.event && user.is_event_staff?(record.event)) ||
    user.vendor?  # Allow vendors to view printing service details
  end

  def create?
    # Org owner can only link services when contractor printing is disabled
    if user.org_owner?
      record&.event && !record.event.allow_contractor_printing_services
    elsif user.organizer? || (record&.event && user.is_event_staff?(record.event))
      true
    elsif user.exhibition_contractor? && record&.event && record.event.allow_contractor_printing_services && user.exhibition_contractor_for?(record.event)
      true
    else
      false
    end
  end

  def update?
    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event))
  end

  def destroy?
    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
    (user.exhibition_contractor? && record&.event && record.event.allow_contractor_printing_services && user.exhibition_contractor_for?(record.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor? && user.exhibition_contractor_profile.present?
        scope.joins(event: :event_exhibition_contractors)
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.vendor?
        scope.joins(:printing_service)
             .joins(event: :event_vendors)
             .where(printing_services: { status: PrintingService.statuses[:active] })
             .where(event_vendors: { vendor_id: user.id })
             .where(events: { use_exhibitor_kit: true })
      elsif user.is_staff?
        scope.joins(event: :event_assignments)
             .where(event_assignments: { user_id: user.id, role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]] })
      else
        scope.none
      end
    end
  end
end
