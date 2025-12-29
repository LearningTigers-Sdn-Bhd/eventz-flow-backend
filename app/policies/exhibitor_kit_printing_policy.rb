class ExhibitorKitPrintingPolicy < ApplicationPolicy
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
        # Contractors can only see printings for events where contractor printing is enabled
        # and they are assigned to the event, and the printing service belongs to them
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .joins(printing_service: {})
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
             .where(events: { allow_contractor_printing_services: true })
             .where(printing_services: { user_id: user.id })
      elsif user.exhibitor?
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' })
      else
        scope.none
      end
    end
  end
end
