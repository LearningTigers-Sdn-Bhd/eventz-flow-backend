class EventTicketSeatPolicy < ApplicationPolicy
  def index?
    # Public access allowed for viewing seats
    true
  end

  def show?
    true
  end

  def create?
    admin_allowed?
  end

  def update?
    admin_allowed?
  end

  def destroy?
    admin_allowed?
  end

  def lock?
    # Public users can lock seats for reservation
    true
  end

  def unlock?
    # Public users can unlock seats (cancel selection)
    true
  end

  private

  def admin_allowed?
    return false unless user.present?
    
    # Resolve the event from the record (EventTicketSeat -> Section -> Venue -> Session -> Event)
    event = record.event_seat_section&.event_seat_venue&.event_seat_session&.event
    return false unless event.present?
    return false unless event.use_seat_ticketing?

    user.is_org_owner? || 
    user.is_organizer? || 
    user.is_event_admin?(event)
  end
end
