class GroupAffiliatePolicy < ApplicationPolicy
  # Only org_owner can assign/remove vendors from groups
  def create?
    user&.is_org_owner?
  end

  def destroy?
    user&.is_org_owner?
  end
end
