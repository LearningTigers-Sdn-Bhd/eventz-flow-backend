class EmailDeliveryPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.all if user.org_owner?

      scope.none
    end
  end

  def index?
    user.org_owner?
  end

  def show?
    index?
  end

  def resend?
    index? && record.eligible_for_manual_resend?
  end
end
