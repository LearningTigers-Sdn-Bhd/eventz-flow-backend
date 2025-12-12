class CustomRequestPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || assigned_contractor_access? || owns_event_vendor_assigned_request?
  end

  def show?
    user.org_owner? || user.organizer? || assigned_contractor_access? || owns_event_vendor_assigned_request?
  end

  def create?
    (user.admin? || user.organizer?) || owns_event_vendor_assigned_request?
  end

  def update?
    (user.admin? || user.organizer?) || owns_event_vendor_assigned_request? || assigned_contractor_access?
  end

  def destroy?
    (user.admin? || user.organizer?) || owns_event_vendor_assigned_request?
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor? && user.exhibition_contractor_profile.present?
        # Contractors can see all custom requests in events they are assigned to
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_vendor?
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendors: { vendor_id: user.id })
      else
        scope.none
      end
    end
  end

  private

  def assigned_contractor_access?
    user.is_exhibition_contractor? &&
      record&.exhibitor_kit&.event_vendor&.event &&
      user.exhibition_contractor_profile.present? && # Ensure profile exists
      user.exhibition_contractor_profile.events.exists?(id: record.exhibitor_kit.event_vendor.event.id)
  end

  def owns_event_vendor_assigned_request?
    record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event)
  end
end