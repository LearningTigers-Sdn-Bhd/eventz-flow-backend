# app/policies/resource_policy.rb
class ResourcePolicy < ApplicationPolicy
  def index?
    true # All can read
  end

  def show?
    # Public can only see published resources.
    # Staff/authors can see their own unpublished resources.
    return true if record.published?
    return false if user.nil?
    user.is_org_owner? || record.user_id == user.id
  end

  def create?
    user&.is_org_owner? || user&.can_write_resources?
  end

  def update?
    return false if user.nil?
    user.is_org_owner? || (user.can_write_resources? && record.user_id == user.id)
  end

  def destroy?
    update?
  end

  def restore?
    update?
  end

  def force_destroy?
    user&.is_org_owner?
  end

  def approval?
    user&.is_org_owner?
  end

  def approval_index?
    approval?
  end

  def index_owner?
    user&.is_org_owner?
  end
end
