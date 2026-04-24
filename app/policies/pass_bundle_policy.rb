class PassBundlePolicy < ApplicationPolicy
  def index?
    event_policy.show?
  end

  def show?
    event_policy.show?
  end

  def create?
    event_policy.update?
  end

  def update?
    event_policy.update?
  end

  def destroy?
    event_policy.update?
  end

  private

  def event_policy
    EventPolicy.new(user, record.event)
  end

  class Scope < Scope
    def resolve
      allowed_event_ids = EventPolicy::Scope.new(user, Event).resolve.select(:id)
      scope.where(event_id: allowed_event_ids)
    end
  end
end
