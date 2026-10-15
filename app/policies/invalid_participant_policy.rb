class InvalidParticipantPolicy < ApplicationPolicy
  # All invalid-participant actions are authorized through the parent lucky
  # draw session, so an exhibitor can only manage entries on a session they
  # created themselves, never an organizer/admin-owned session.
  def resolve_session
    if record.respond_to?(:lucky_draw_session)
      record.lucky_draw_session
    end
  end

  # index? - event admins, team members, org admins, and exhibitors on their own session
  def index?
    return false if user.blank? || record.blank?
    session = resolve_session
    return false unless session

    return true if user.is_event_team_member?(session.event)

    LuckyDrawSessionPolicy.new(user, session).show?
  end

  # create? - event admins, team members, org admins
  def create?
    index?
  end

  # destroy? - event admins, team members, org admins
  def destroy?
    index?
  end

  # notify? - same as index? (can notify if can view)
  def notify?
    index?
  end

  # destroy_all? - event admins, team members, org admins
  def destroy_all?
    index?
  end
end