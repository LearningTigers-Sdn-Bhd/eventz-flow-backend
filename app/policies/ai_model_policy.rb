class AiModelPolicy < ApplicationPolicy
  def create?
    user.is_org_owner?
  end

  def update?
    user.is_org_owner?
  end

  def destroy?
    user.is_org_owner?
  end

  def set_default?
    user.is_org_owner?
  end
end
