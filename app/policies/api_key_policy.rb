class ApiKeyPolicy < ApplicationPolicy
  # Ensure the scope only returns active keys for the current user
  class Scope < Scope
    def resolve
      scope.where(user: user, is_active: true)
    end
  end

  # Only the user associated with the key can view it (indirectly via index/show scope)
  def show?
    record.user == user && user.is_organizer?
  end

  # Only org_owners and organizers can create keys
  def create?
    user.is_organizer?
  end

  # Only org_owners and organizers can manage (index) the keys
  def index?
    user.is_organizer?
  end

  # Only org_owners and organizers can destroy/revoke keys
  def destroy?
    user.is_organizer?
  end
end
