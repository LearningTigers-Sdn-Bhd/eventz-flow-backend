class EventRentableItemPolicy < ApplicationPolicy
  def index?
    return false unless exhibitor_management_enabled?

    user.org_owner? ||
      user.organizer? ||
      (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) ||
      (record&.event && user.is_event_staff?(record.event)) ||
      user.exhibitor? ||
      user.vendor?  # Allow vendors to browse items
  end

  def show?
    return false unless exhibitor_management_enabled?

    user.org_owner? ||
      user.organizer? ||
      (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) ||
      (record&.event && user.is_event_staff?(record.event)) ||
      user.vendor?  # Allow vendors to view item details
  end

  def create?
    return false unless exhibitor_management_enabled?

    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
      (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event))
  end

  def update?
    return false unless exhibitor_management_enabled?

    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
      (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event))
  end

  def destroy?
    return false unless exhibitor_management_enabled?

    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
      (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor? && user.exhibition_contractor_profile.present?
        scope.joins(event: :event_exhibition_contractors)
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.vendor?
        # "exhibitor" isn't a real user role in practice — Exhibitor vs
        # Merchant is the EventVendor STI type, so filter on that directly
        # rather than a live event flag (which can drift from the type
        # stamped on the vendor record at registration time).
        scope.joins(:rentable_item)
             .joins(event: :event_vendors)
             .where(rentable_items: { status: RentableItem.statuses[:active] })
             .where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' })
      elsif user.assigned_events.present? && user.is_staff?
        scope.joins(event: :event_assignments)
             .where(event_assignments: { user_id: user.id,
                                         role: [EventAssignment.roles[:event_admin],
                                                EventAssignment.roles[:event_team_member]] })
      else
        scope.none
      end
    end
  end

  private

  def exhibitor_management_enabled?
    user.org_owner? || record&.event&.enable_exhibitor_management?
  end
end
