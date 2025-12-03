class ExhibitorKitItemPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || user.is_exhibition_contractor? || user.is_event_vendor?(@record.exhibitor_kit.event_vendor.event)
  end

  def show?
    user.org_owner? || user.organizer? || user.is_exhibition_contractor? || user.is_event_vendor?(@record.exhibitor_kit.event_vendor.event)
  end

  def create?
    user.org_owner? || user.organizer? || user.is_event_vendor?(@record.exhibitor_kit.event_vendor.event)
  end

  def update?
    user.org_owner? || user.organizer? || user.is_event_vendor?(@record.exhibitor_kit.event_vendor.event)
  end

  def destroy?
    user.org_owner? || user.organizer? || user.is_event_vendor?(@record.exhibitor_kit.event_vendor.event)
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor?
        # Contractors can see all items in events they are assigned to
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_event_vendor? # Exhibitor (vendor) can see their own kit items
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendor: { vendor_id: user.id })
      else
        scope.none
      end
    end
  end
end
