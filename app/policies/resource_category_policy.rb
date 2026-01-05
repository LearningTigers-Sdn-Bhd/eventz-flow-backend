# app/policies/resource_category_policy.rb
class ResourceCategoryPolicy < ApplicationPolicy
  def index?
    true # All can read
  end

  def show?
    true # All can read
  end

  def create?
    user&.is_org_owner? || user&.can_write_resources?
  end

  def update?
    user&.is_org_owner?
  end

  def destroy?
    user&.is_org_owner?
  end

  def force_destroy?
    user&.is_org_owner?
  end

  def restore?
    user&.is_org_owner?
  end
end
