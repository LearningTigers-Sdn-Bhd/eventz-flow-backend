class ExhibitorKitPaymentPolicy < ApplicationPolicy
  def index?
    admin_or_organizer_or_contractor?
  end

  def show?
    admin_or_organizer_or_contractor? || (user.exhibitor? && user.id == record.exhibitor_kit.event_vendor.vendor_id)
  end

  def create?
    (user.admin? || user.organizer?) || (user.exhibitor? && user.id == record.exhibitor_kit.event_vendor.vendor_id)
  end

  def update?
    # Only exhibitor can update if status is pending (to submit proof)
    (user.exhibitor? && user.id == record.exhibitor_kit.event_vendor.vendor_id && record.pending?) ||
    # Organizer/Admin/Contractor can update (verify/reject)
    admin_or_organizer_or_contractor?
  end

  def destroy?
    user.admin_or_organizer?
  end

  def verify?
    admin_or_organizer_or_contractor?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.organizer?
        # Organizer sees payments for events they are assigned to
        scope.joins(exhibitor_kit: {event_vendor: :event}).where(events: { id: user.assigned_events.pluck(:id) })
      elsif user.exhibition_contractor?
        scope.joins(exhibitor_kit: {event_vendor: :event}).where(events: { id: user.events_as_contractor.pluck(:id) })
      elsif user.exhibitor?
        scope.joins(exhibitor_kit: :event_vendor).where(event_vendors: { vendor_id: user.id })
      else
        scope.none
      end
    end
  end

  private

  def admin_or_organizer_or_contractor?
    user.admin? || user.organizer? || user.exhibition_contractor?
  end
end
