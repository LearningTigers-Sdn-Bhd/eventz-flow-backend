class EventLeadPolicy < ApplicationPolicy
  # Index: Show all leads for org_owner/organizer/event_admin/event_team_member
  # Vendors can only see their own leads
  def index?
    return false unless user.present?

    event = record # record is the event in this context

    # Org-level permissions: see all leads
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level staff: see all leads for their event
    return true if user.is_event_admin?(event) || user.is_event_team_member?(event)

    # Vendors: can see leads (but scope will filter to only their leads)
    return true if user.is_event_vendor?(event)

    false
  end

  # Create: Vendors can create leads, staff can also create
  def create?
    return false unless user.present?

    event_vendor = record # record is the event_vendor in this context
    event = event_vendor.event

    # Org-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level staff
    return true if user.is_event_admin?(event) || user.is_event_team_member?(event)

    # Vendor can only create leads for themselves
    return true if user.is_vendor? && event_vendor.vendor_id == user.id

    false
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Org Owner/Organizer: See all leads
      return scope.all if user.is_org_owner? || user.is_organizer?

      # Event staff: See all leads for their events
      event = @scope.is_a?(ActiveRecord::Relation) ? nil : @scope
      if user.is_event_admin?(event) || user.is_event_team_member?(event)
        return scope.all
      end

      # Vendors: Only see leads they captured (their event_vendor records)
      if user.is_vendor?
        vendor_event_vendor_ids = EventVendor.where(vendor_id: user.id).pluck(:id)
        return scope.where(event_vendor_id: vendor_event_vendor_ids)
      end

      scope.none
    end
  end
end
