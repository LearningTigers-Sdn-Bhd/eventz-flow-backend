class AiModelPolicy < ApplicationPolicy
  def create?
    own_record?
  end

  def update?
    own_record?
  end

  def destroy?
    own_record?
  end

  def set_default?
    own_record?
  end

  private

  def own_record?
    user.is_org_owner? && record.ai_integration.user_id == user.id
  end
end
