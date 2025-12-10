class GiftPolicy < ApplicationPolicy
  # Convenience method for delegating to the parent resource policy
  def event_policy
    return nil if record.blank?
    event = resolve_event
    return nil unless event
    
    Pundit.policy(user, event)
  rescue NoMethodError
    nil
  end

  def resolve_event
    if record.respond_to?(:event)
      record.event
    elsif record.respond_to?(:lucky_draw_session)
      record.lucky_draw_session&.event
    else
      nil
    end
  end

  # index? - event admins, team members, org admins
  def index?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level permissions
    event = resolve_event
    return false unless event

    user.is_event_admin?(event) || user.is_event_team_member?(event)
  end

  # show? - event admins, team members, org admins
  def show?
    index?
  end

  # create? - event admins and org admins
  def create?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    # Event-level permissions
    event = resolve_event
    return false unless event

    user.is_event_admin?(event)
  end

  # update? - event admins and org admins
  def update?
    create?
  end

  # destroy? - event admins and org admins
  def destroy?
    create?
  end
end