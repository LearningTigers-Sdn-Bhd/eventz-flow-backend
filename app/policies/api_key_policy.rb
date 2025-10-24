class ApiKeyPolicy < ApplicationPolicy
  # Ensure the scope only returns active keys for the current user
  class Scope < Scope
    def resolve
      scope.where(user: user, is_active: true)
    end
  end

  # Only the user associated with the key can view it (indirectly via index/show scope)
  def show?
    record.user == user && user.org_owner?
  end

  # Only org_owners can create keys
  def create?
    user.org_owner?
  end

  # Only org_owners can manage (index) the keys
  def index?
    user.org_owner?
  end

  # Only org_owners can destroy/revoke keys
  def destroy?
    user.org_owner?
  end
end
