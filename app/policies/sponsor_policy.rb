class SponsorPolicy < ApplicationPolicy
  def index?; manage?; end
  def show?; manage?; end
  def create?; manage?; end
  def update?; manage?; end
  def destroy?; manage?; end

  def lookup?
    # event_admin can lookup sponsors (read-only)
    manage? || user.event_assignments.exists?(role: :event_admin)
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner_or_organizer? || user.event_assignments.exists?(role: :event_admin)
        scope.all
      else
        scope.none
      end
    end
  end

  private

  def manage?
    user.is_org_owner_or_organizer?
  end
end
