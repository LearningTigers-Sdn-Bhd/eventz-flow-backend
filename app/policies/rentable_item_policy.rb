class RentableItemPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || user.exhibition_contractor?
  end

  def show?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record.user_id == user.id)
  end

  def create?
    user.org_owner? || user.organizer? || user.exhibition_contractor?
  end

  def update?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record.user_id == user.id)
  end

  def destroy?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record.user_id == user.id)
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor?
        scope.where(user_id: user.id)
      else
        scope.none
      end
    end
  end
end
