# app/policies/resource_lead_policy.rb
class ResourceLeadPolicy < ApplicationPolicy
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
