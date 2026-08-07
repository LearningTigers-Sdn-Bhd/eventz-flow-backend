# app/policies/vendor_profile_policy.rb
class VendorProfilePolicy < ApplicationPolicy
  # NOTE: user = @current_user, record = the VendorProfile instance being acted upon

  def show?
    # Ensure the profile belongs to an actual vendor
    return false unless record.vendor&.vendor?

    # 1. Vendor can view their own profile
    # 2. Org owners can view any vendor profile
    # 3. Organizers can view profiles of vendors they created
    # 4. Event admins can view vendors assigned to events they manage
    user.org_owner? ||
      record.vendor_id == user.id ||
      (user.organizer? && record.vendor.created_by_id == user.id) ||
      event_staff_for_vendor?
  end

  def update?
    return false unless record.vendor&.vendor?

    # Vendor owners, the creator, and staff on a shared event
    user.org_owner? ||
      record.vendor_id == user.id ||
      (user.organizer? && record.vendor.created_by_id == user.id) ||
      event_staff_for_vendor?
  end

  private

  # Any event assignment counts, matching VendorPolicy's shared-event team rule.
  def event_staff_for_vendor?
    EventVendor.where(vendor_id: record.vendor_id)
               .where(event_id: user.event_assignments.select(:event_id))
               .exists?
  end
end
