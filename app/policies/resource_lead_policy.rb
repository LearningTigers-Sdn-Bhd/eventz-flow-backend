# app/policies/resource_lead_policy.rb
class ResourceLeadPolicy < ApplicationPolicy
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
    true # Public action
  end

  def metrics?
    user&.is_org_owner?
  end
end
