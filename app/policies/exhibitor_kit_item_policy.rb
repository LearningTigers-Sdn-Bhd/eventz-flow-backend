class ExhibitorKitItemPolicy < ApplicationPolicy
  def index?
    user.is_org_owner_or_organizer? ||
    (record&.exhibitor_kit&.event_vendor&.vendor_id == user.id) || # Exhibitor who owns the kit
    (user.is_exhibition_contractor? && record&.exhibitor_kit&.event_vendor&.event && user.exhibition_contractor_for?(record.exhibitor_kit.event_vendor.event))
  end

  def show?
    user.is_org_owner_or_organizer? ||
    (record&.exhibitor_kit&.event_vendor&.vendor_id == user.id) || # Exhibitor who owns the kit
    (user.is_exhibition_contractor? && record&.exhibitor_kit&.event_vendor&.event && user.exhibition_contractor_for?(record.exhibitor_kit.event_vendor.event))
  end

  def create?
    user.is_org_owner_or_organizer? ||
    (record&.exhibitor_kit&.event_vendor&.vendor_id == user.id) || # Exhibitor who owns the kit
    (user.is_exhibition_contractor? && record&.exhibitor_kit&.event_vendor&.event && user.exhibition_contractor_for?(record.exhibitor_kit.event_vendor.event))
  end

  def update?
    user.is_org_owner_or_organizer? ||
    (record&.exhibitor_kit&.event_vendor&.vendor_id == user.id) || # Exhibitor who owns the kit
    (user.is_exhibition_contractor? && record&.exhibitor_kit&.event_vendor&.event && user.exhibition_contractor_for?(record.exhibitor_kit.event_vendor.event))
  end

  def destroy?
    user.is_org_owner_or_organizer? ||
    (record&.exhibitor_kit&.event_vendor&.vendor_id == user.id) || # Exhibitor who owns the kit
    (user.is_exhibition_contractor? && record&.exhibitor_kit&.event_vendor&.event && user.exhibition_contractor_for?(record.exhibitor_kit.event_vendor.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.is_exhibition_contractor? && user.exhibition_contractor_profile.present?
        # Contractors can see all items in events they are assigned to
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.exhibitor? # Change to user.exhibitor?
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' }) # Filter for exhibitor's items
      else
        scope.none
      end
    end
  end
end
