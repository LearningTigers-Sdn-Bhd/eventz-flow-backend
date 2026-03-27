class ExhibitorBoothPriceTierPolicy < ApplicationPolicy
  def index?
    allowed?
  end

  def show?
    allowed?
  end

  def create?
    allowed?
  end

  def update?
    allowed?
  end

  def destroy?
    allowed?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.org_owner? || user.organizer?

      scope.joins(exhibitor_booth_price: :event)
           .where(events: {
             id: user.event_assignments
                     .where(role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]])
                     .select(:event_id)
           })
    end
  end

  private

  def allowed?
    event = record&.exhibitor_booth_price&.event
    user.org_owner? || user.organizer? || (event.present? && user.is_event_staff?(event))
  end
end
