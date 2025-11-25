class GroupAffiliatePolicy < ApplicationPolicy
  # Org owners and group managers can assign/remove vendors from groups
  def create?
    user&.is_org_owner? || user&.is_group_manager?(record.group)
  end

  def destroy?
    user&.is_org_owner? || user&.is_group_manager?(record.group)
  end
end
