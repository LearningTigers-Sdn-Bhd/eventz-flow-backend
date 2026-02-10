class EventSeatSessionPolicy < ApplicationPolicy
  def index?
    # Session filtering is done in the controller or via Scope
    true
  end

  def show?
    session = record.is_a?(EventSeatSession) ? record : record.event_seat_venue.event_seat_session
    return true if session.published?
    allowed?
  end

  def create?
    # For create, the record is a new instance.
    # We must ensure the event is set on the record before calling authorize
    allowed?
  end

  def update?
    allowed?
  end

  def bulk_update?
    update?
  end

  def attach_image?
    update?
  end

  def assign_seats?
    update?
  end

  def destroy?
    allowed?
  end

  def archive?
    allowed?
  end

  def restore?
    allowed?
  end

  def force_delete?
    allowed?
  end

  def duplicate?
    allowed?
  end

  private

  def allowed?
    return false unless user.present?
    
    session = record.is_a?(EventSeatSession) ? record : record.event_seat_venue.event_seat_session
    return false unless session&.event.present?
    
    # Policy: Controller cannot be accessed when the event is not set for it (use_seat_ticketing)
    return false unless session.event.use_seat_ticketing?

    # Policy: not event_admin, event_organizer or org_owner
    user.is_org_owner? || 
    user.is_organizer? || 
    user.is_event_admin?(session.event)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      # Base scope: events with seat ticketing enabled
      # (Though the requirement says "cannot be accessed when event is not set for it", 
      # filtering in scope is a good practice too)
      
      if user.is_org_owner? || user.is_organizer?
         return scope.joins(:event).where(events: { use_seat_ticketing: true })
      end

      # For Event Admin (and possibly Team Member, but prompt excluded them explicitly? 
      # "not event_admin, event_organizer or org_owner". 
      # Usually permissions are hierarchical, but I will stick to these 3 roles.)
      
      assigned_event_ids = user.event_assignments
                               .where(role: :event_admin)
                               .pluck(:event_id)

      scope.joins(:event)
           .where(events: { use_seat_ticketing: true })
           .where(events: { id: assigned_event_ids })
    end
  end
end
