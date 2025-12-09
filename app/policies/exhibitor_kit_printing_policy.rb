class ExhibitorKitPrintingPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || (user.is_exhibition_contractor? &&
      record&.exhibitor_kit&.event_vendor&.event &&
      user.exhibition_contractor_profile&.event_exhibition_contractors&.exists?(event_id: record.exhibitor_kit.event_vendor.event_id)) ||
      (record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event))
  end

  def show?
    user.org_owner? || user.organizer? || (user.is_exhibition_contractor? &&
      record&.exhibitor_kit&.event_vendor&.event &&
      user.exhibition_contractor_profile&.event_exhibition_contractors&.exists?(event_id: record.exhibitor_kit.event_vendor.event_id)) ||
      (record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event))
  end

  def create?
    user.org_owner? || user.organizer? || (record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event))
  end

  def update?
    user.org_owner? || user.organizer? || (record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event))
  end

  def destroy?
    user.org_owner? || user.organizer? || (record&.exhibitor_kit&.event_vendor&.event && user.is_event_vendor?(record.exhibitor_kit.event_vendor.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor? && user.exhibition_contractor_profile.present?
        # Contractors can see all items in events they are assigned to
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.is_vendor?
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendor: { vendor_id: user.id })
      else
        scope.none
      end
    end
  end
end
