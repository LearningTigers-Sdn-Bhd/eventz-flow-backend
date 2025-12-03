class ItemCategoryPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || user.exhibition_contractor?
  end

  def show?
    user.org_owner? || user.organizer? || user.exhibition_contractor?
  end

  def create?
    user.org_owner? || user.organizer?
  end

  def update?
    user.org_owner? || user.organizer?
  end

  def destroy?
    user.org_owner? || user.organizer?
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer? || user.exhibition_contractor?
        scope.all
      else
        scope.none
      end
    end
  end
end
