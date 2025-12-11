class EventRentableItemPolicy < ApplicationPolicy
  def index?
    user.org_owner? || 
    user.organizer? || 
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) || 
    (record&.event && user.is_event_staff?(record.event)) || 
    user.exhibitor? ||
    user.vendor?  # Allow vendors to browse items
  end

  def show?
    user.org_owner? || 
    user.organizer? || 
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event)) || 
    (record&.event && user.is_event_staff?(record.event)) ||
    user.vendor?  # Allow vendors to view item details
  end

  def create?
    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event))
  end

  def update?
    user.org_owner? || user.organizer? || (record&.event && user.is_event_staff?(record.event)) ||
    (user.exhibition_contractor? && record&.event && user.exhibition_contractor_for?(record.event))
  end

  def destroy?
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
      elsif user.exhibitor?
        scope.joins(:rentable_item)
             .joins(event: :event_vendors)
             .where(rentable_items: { status: RentableItem.statuses[:active] })
             .where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' })
      elsif user.vendor?
        scope.joins(:rentable_item)
             .joins(event: :event_vendors)
             .where(rentable_items: { status: RentableItem.statuses[:active] })
             .where(event_vendors: { vendor_id: user.id })
             .where(events: { use_exhibitor_kit: true })
      elsif user.assigned_events.present? && user.is_staff?
        scope.joins(event: :event_assignments)
             .where(event_assignments: { user_id: user.id, role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]] })
      else
        scope.none
      end
    end
  end
end
