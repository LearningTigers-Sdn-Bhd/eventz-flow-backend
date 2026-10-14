# The connection (counter service URL + API key) is org-owner-only: it decides
# which live data an event can read. Record is a PeopleCounterConnection (new or saved).
class PeopleCounterConnectionPolicy < ApplicationPolicy
  def show?
    manage?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def test?
    manage?
  end

  private

  def manage?
    user.present? && record.present? && user.is_org_owner? && EventPolicy.new(user, record.event).update?
  end
end
