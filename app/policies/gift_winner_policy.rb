class GiftWinnerPolicy < ApplicationPolicy
  # All winner actions are authorized through the parent lucky draw session,
  # so an exhibitor can only record winners on a session they created
  # themselves, never an organizer/admin-owned session.
  def resolve_session
    return nil unless record.respond_to?(:gift)

    record.gift&.lucky_draw_session
  end

  # create? - delegates to the session: org admins see all, exhibitors only their own
  def create?
    return false if user.blank? || record.blank?
    session = resolve_session
    return false unless session

    return true if user.is_event_team_member?(session.event)

    LuckyDrawSessionPolicy.new(user, session).show?
  end

  # destroy? - event admins, team members, org admins
  def destroy?
    create?
  end

  # notify? - same as create? (can notify if can manage winners)
  def notify?
    create?
  end

  # bulk? - same as create? (for bulk winner assignment)
  def bulk?
    create?
  end
end
