# app/policies/vendor_profile_policy.rb
class VendorProfilePolicy < ApplicationPolicy
  # Note: user = @current_user, record = the VendorProfile instance being acted upon

  def show?
    # Ensure the profile belongs to an actual vendor
    return false unless record.vendor&.vendor?
    
    # 1. Vendor can view their own profile
    # 2. Org owners can view any vendor profile
    # 3. Organizers can view profiles of vendors they created
    user.org_owner? || 
      record.vendor_id == user.id || 
      (user.organizer? && record.vendor.created_by_id == user.id)
  end

  def update?
    # Same rules as show? for vendor profiles
    show?
  end
end
