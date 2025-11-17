class GroupPolicy < ApplicationPolicy
  # --- Index: All authenticated users can see groups (filtered by scope) ---
  def index?
    user.present?
  end

  # --- Show: Visibility based on role and membership ---
  def show?
    return false if record.blank?

    # Org owner sees all groups
    return true if user.is_org_owner?

    # Vendors see groups they're assigned to
    if user.vendor?
      return record.group_affiliate&.vendor_id == user.id
    end

    # Organizers and members see groups they belong to
    record.group_members.exists?(user_id: user.id)
  end

  # --- Create: Only org_owner can create groups ---
  def create?
    user&.is_org_owner?
  end

  # --- Update: org_owner and group managers can update group details ---
  def update?
    return false if user.blank? || record.blank?

    # Org owner can update any group
    return true if user.is_org_owner?

    # Group managers (has_manager_access=true) can update their group
    user.is_group_manager?(record)
  end

  # --- Destroy: Only org_owner can delete groups ---
  def destroy?
    user&.is_org_owner?
  end

  # --- Scope: Filters groups based on user role and membership ---
  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Org owner sees all groups
      return scope.all if user.is_org_owner?

      # Vendors see groups they're assigned to via group_affiliate
      if user.vendor?
        return scope.joins(:group_affiliate).where(group_affiliates: { vendor_id: user.id }).distinct
      end

      # Organizers and members see groups they belong to via group_members
      scope.joins(:group_members).where(group_members: { user_id: user.id }).distinct
    end
  end
end
