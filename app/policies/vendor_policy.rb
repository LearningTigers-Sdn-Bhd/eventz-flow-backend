# app/policies/vendor_policy.rb
class VendorPolicy < UserPolicy
  # Note: user = @current_user, record = the User instance with vendor role

  # Inherits Scope from UserPolicy which already handles:
  # - Org owners can see all users
  # - Organizers can see users they created
  # - Members can only see themselves

  def index?
    # Only organizers and org_owners can list vendors
    user.organizer? || user.org_owner?
  end

  def show?
    # Organizers and org_owners can view vendor details
    # Vendors can view their own details
    user.org_owner? || user.organizer? || record == user
  end

  def create?
    # Only organizers and org_owners can create vendor accounts
    user.organizer? || user.org_owner?
  end

  def update?
    # Org owners can update any vendor
    # Organizers can update vendors they created
    user.org_owner? || (user.organizer? && record.created_by_id == user.id)
  end

  def toggle_status?
    # Same rules as update
    update?
  end

  def destroy?
    # Org owners can delete any vendor
    # Organizers can delete vendors they created
    user.org_owner? || (user.organizer? && record.created_by_id == user.id)
  end
end
