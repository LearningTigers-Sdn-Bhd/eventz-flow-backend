class ExhibitorBoothPricePolicy < ApplicationPolicy
  def create?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  def update?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  def destroy?
    user.org_owner? || user.organizer? || user.is_event_staff?(record.event)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.org_owner? || user.organizer?

      scope.joins(:event)
           .where(events: { id: user.event_assignments
             .where(role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]])
             .select(:event_id) })
    end
  end
end
