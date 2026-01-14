# app/policies/resource_permission_policy.rb
class ResourceWritePermissionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def index?
    user&.is_org_owner?
  end

  def show?
    user&.is_org_owner?
  end

  def create?
    user&.is_org_owner?
  end

  def update?
    user&.is_org_owner?
  end

  def destroy?
    user&.is_org_owner?
  end
end
