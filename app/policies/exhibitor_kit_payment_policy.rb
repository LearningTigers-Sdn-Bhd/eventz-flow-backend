class ExhibitorKitPaymentPolicy < ApplicationPolicy
  def index?
    user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.exhibitor_kit.event) || record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def show?
    user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.exhibitor_kit.event) || record.exhibitor_kit.event_vendor.vendor_id == user.id
  end

  def create?
    user.is_org_owner_or_organizer? || (record.present? && user.vendor? && record.exhibitor_kit && record.exhibitor_kit.event_vendor.vendor_id == user.id)
  end

  def destroy?
    user.is_org_owner_or_organizer? || (record.present? && user.vendor? && record.exhibitor_kit && record.exhibitor_kit.event_vendor.vendor_id == user.id && record.status == 'pending') # Only pending for exhibitor
  end

  def update?
    # Exhibitor can update payment_proof_url, external_ref, notes, and status to 'submitted'
    if record.exhibitor_kit.event_vendor.vendor_id == user.id
      # Permit these fields only if the status is currently 'pending', 'submitted', or 'rejected'
      # so that an exhibitor can submit or resubmit payment proof
      if record.status == 'pending' || record.status == 'submitted' || record.status == 'rejected'
        return true
      end
    end

    # Organizer/Admin/Contractor (payee) can approve/reject
    user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.exhibitor_kit.event)
  end

  def verify?
    user.is_org_owner_or_organizer? || (user.is_exhibition_contractor? && record.payee == user)
  end

  class Scope < Scope
    def resolve
      if user.org_owner?
        scope.all
      elsif user.organizer?
        # Organizer sees payments for events they have created or are assigned as staff
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_assignments } })
             .where(event_assignments: { user_id: user.id })
      elsif user.is_exhibition_contractor?
        # Contractor only sees payments where they are the payee (for their items/services)
        scope.joins(exhibitor_kit: { event_vendor: { event: :event_exhibition_contractors } })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
             .where(payee_id: user.id)
      elsif user.vendor?
        # Exhibitor sees payments for their exhibitor kits
        scope.joins(exhibitor_kit: :event_vendor)
             .where(event_vendors: { vendor_id: user.id, type: 'Exhibitor' })
      else
        scope.none
      end
    end
  end

  def permitted_attributes_for_update
    if record.exhibitor_kit.event_vendor.vendor_id == user.id # Exhibitor (vendor)
      if record.status == 'pending' || record.status == 'submitted' || record.status == 'rejected'
        [:payment_proof, :external_ref, :note, :payment_source]
      else
        [] # Exhibitor cannot change anything once payment is verified
      end
    elsif user.is_org_owner_or_organizer? # Organizer/Admin
      [:status, :note, :paid_at] # Can change status, add notes, and paid_at
    elsif user.exhibition_contractor_for?(record.exhibitor_kit.event) # Contractor (if payee)
      # Contractor can verify/reject payments made to them
      if record.payee == user
        [:status, :note, :paid_at]
      else
        []
      end
    else
      []
    end
  end
end