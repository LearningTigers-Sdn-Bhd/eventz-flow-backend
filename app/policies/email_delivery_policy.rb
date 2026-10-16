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

  def summary?
    index?
  end

  # Retention is a write that deletes data; keep it tied to its own rule so
  # widening read access later can't silently widen it.
  def settings?
    user.org_owner?
  end

  def update_settings?
    user.org_owner?
  end

  def resend?
    index? && record.eligible_for_manual_resend?
  end
end
