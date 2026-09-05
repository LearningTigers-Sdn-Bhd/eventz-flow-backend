class ScanLogPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    index?
  end

  class Scope < Scope
    def resolve
      scope.where(event: Pundit.policy_scope(user, Event))
    end
  end
end
