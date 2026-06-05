class ExhibitorTeamMemberPaymentPolicy < ApplicationPolicy
  def index?
    user.is_org_owner_or_organizer? || record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def show?
    user.is_org_owner_or_organizer? || record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def create?
    # Only the vendor (exhibitor) of this kit can create a payment
    user.vendor? && record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def create_order?
    user.vendor? && record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def verify?
    user.vendor? && record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def update?
    # Vendor can update payment_proof, external_ref, notes when status allows
    if (record.exhibitor_kit.event_vendor.vendor_id == user.id) && %w[pending submitted
                                                                      rejected].include?(record.status)
      return true
    end

    # Organizer/Admin can verify/reject
    user.is_org_owner_or_organizer?
  end

  class Scope < Scope
    def resolve
      if user.org_owner?
        scope.all
      elsif user.organizer?
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_assignments } })
             .where(event_assignments: { user_id: user.id })
      elsif user.vendor?
        scope.joins(exhibitor_kit: :event_vendor)
             .where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' })
      else
        scope.none
      end
    end
  end

  def permitted_attributes_for_update
    if record.exhibitor_kit.event_vendor.vendor_id == user.id # Vendor
      if %w[pending submitted rejected].include?(record.status)
        %i[payment_proof external_ref note payment_source]
      else
        []
      end
    elsif user.is_org_owner_or_organizer? # Organizer/Admin
      %i[status note paid_at]
    else
      []
    end
  end
end
