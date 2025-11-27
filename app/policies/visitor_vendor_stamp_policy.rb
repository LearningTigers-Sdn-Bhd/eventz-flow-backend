class VisitorVendorStampPolicy < ApplicationPolicy
  # Index: Show all stamps for org_owner/organizer/event_admin/event_team_member
  # Vendors can only see their own stamps
  def index?
    return false unless user.present?
    
    event = record # record is the event in this context
    
    # Org-level permissions: see all stamps
    return true if user.is_org_owner? || user.is_organizer?
    
    # Event-level staff: see all stamps for their event
    return true if user.is_event_admin?(event) || user.is_event_team_member?(event)
    
    # Vendors: can see stamps (but scope will filter to only their stamps)
    return true if user.is_event_vendor?(event)
    
    false
  end

  # Create: Vendors can create stamps, staff can also create
  def create?
    return false unless user.present?
    
    event_vendor = record # record is the event_vendor in this context
    event = event_vendor.event
    
    # Org-level permissions
    return true if user.is_org_owner? || user.is_organizer?
    
    # Event-level staff
    return true if user.is_event_admin?(event) || user.is_event_team_member?(event)
    
    # Vendor can only create stamps for themselves
    return true if user.is_vendor? && event_vendor.vendor_id == user.id
    
    false
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Get the event from the context (passed via policy_scope)
      # This assumes you'll pass the event as context
      event = @scope.is_a?(ActiveRecord::Relation) ? nil : @scope
      
      # Org Owner/Organizer: See all stamps
      return scope.all if user.is_org_owner? || user.is_organizer?
      
      # Event staff: See all stamps for their events
      if user.is_event_admin?(event) || user.is_event_team_member?(event)
        return scope.all
      end
      
      # Vendors: Only see stamps they created (their event_vendor records)
      if user.is_vendor?
        vendor_event_vendor_ids = EventVendor.where(vendor_id: user.id).pluck(:id)
        return scope.where(event_vendor_id: vendor_event_vendor_ids)
      end
      
      scope.none
    end
  end
end
