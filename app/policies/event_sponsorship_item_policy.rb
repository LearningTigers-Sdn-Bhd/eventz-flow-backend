class EventSponsorshipItemPolicy < ApplicationPolicy
  def index?
    user.is_org_owner_or_organizer? || user.event_assignments.exists?(role: :event_admin)
  end

  def show?; allowed?; end
  def create?; allowed?; end
  def update?; allowed?; end
  def destroy?; allowed?; end

  class Scope < Scope
    def resolve
      if user.is_org_owner_or_organizer?
        scope.all
      else
        assigned_event_ids = user.event_assignments.where(role: :event_admin).pluck(:event_id)
        scope.joins(event_sponsorship: :event).where(events: { id: assigned_event_ids })
      end
    end
  end

  private

  def allowed?
    return false unless user && record
    
    sponsorship = record.is_a?(EventSponsorshipItem) ? record.event_sponsorship : nil
    event = sponsorship&.event
    
    if event
      user.is_org_owner_or_organizer? || user.is_event_admin?(event)
    else
      false
    end
  end
end
