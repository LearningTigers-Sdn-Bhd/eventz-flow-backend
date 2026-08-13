class GiftPolicy < ApplicationPolicy
  # All gift actions are authorized through the parent lucky draw session,
  # so an exhibitor can only manage prizes on a session they created
  # themselves, never an organizer/admin-owned session.
  def resolve_session
    record.lucky_draw_session if record.respond_to?(:lucky_draw_session)
  end

  def index?
    return false if user.blank? || record.blank?
    session = resolve_session
    return false unless session

    return true if user.is_event_team_member?(session.event)

    LuckyDrawSessionPolicy.new(user, session).show?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end