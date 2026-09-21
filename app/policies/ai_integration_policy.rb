class AiIntegrationPolicy < ApplicationPolicy
  def index?
    user.is_org_owner?
  end

  def create?
    user.is_org_owner?
  end

  def available_models?
    user.is_org_owner?
  end

  def import_models?
    user.is_org_owner?
  end

  def update?
    user.is_org_owner?
  end

  def destroy?
    user.is_org_owner?
  end
end
