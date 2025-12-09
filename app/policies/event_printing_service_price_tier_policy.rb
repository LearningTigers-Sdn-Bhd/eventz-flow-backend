class EventPrintingServicePriceTierPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record&.event_printing_service&.event && user.exhibition_contractor_for?(record.event_printing_service.event)) || (record&.event_printing_service&.event && user.is_event_staff?(record.event_printing_service.event))
  end

  def show?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record&.event_printing_service&.event && user.exhibition_contractor_for?(record.event_printing_service.event)) || (record&.event_printing_service&.event && user.is_event_staff?(record.event_printing_service.event))
  end

  def create?
    user.org_owner? || user.organizer? || (record&.event_printing_service&.event && user.is_event_staff?(record.event_printing_service.event)) ||
    (user.exhibition_contractor? && record&.event_printing_service&.event && user.exhibition_contractor_for?(record.event_printing_service.event))
  end

  def update?
    user.org_owner? || user.organizer? || (record&.event_printing_service&.event && user.is_event_staff?(record.event_printing_service.event)) ||
    (user.exhibition_contractor? && record&.event_printing_service&.event && user.exhibition_contractor_for?(record.event_printing_service.event))
  end

  def destroy?
    user.org_owner? || user.organizer? || (record&.event_printing_service&.event && user.is_event_staff?(record.event_printing_service.event)) ||
    (user.exhibition_contractor? && record&.event_printing_service&.event && user.exhibition_contractor_for?(record.event_printing_service.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor? && user.exhibition_contractor_profile.present?
        scope.joins(event_printing_service: { event: :event_exhibition_contractors })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_staff? # This is a global check if user is staff (org_owner, organizer, member)
        scope.joins(event_printing_service: { event: :event_assignments })
             .where(event_assignments: { user_id: user.id })
             .where(event_assignments: { role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]] })
      else
        scope.none
      end
    end
  end
end
