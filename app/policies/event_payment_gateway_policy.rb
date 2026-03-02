class EventPaymentGatewayPolicy < ApplicationPolicy
  def show?
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record.event)
  end

  def create?
    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record.event)
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
