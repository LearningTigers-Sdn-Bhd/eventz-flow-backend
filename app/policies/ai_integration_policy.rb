class AiIntegrationPolicy < ApplicationPolicy
  def index?
    user.is_org_owner?
  end

  def create?
    user.is_org_owner?
  end

  def available_models?
    own_record?
  end

  def import_models?
    own_record?
  end

  def update?
    own_record?
  end

  def destroy?
    own_record?
  end

  private

  def own_record?
    user.is_org_owner? && record.user_id == user.id
  end
end
