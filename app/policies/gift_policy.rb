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

  # index? - event admins, team members, org admins, and exhibitors viewing their own event's draw
  def index?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    event = resolve_event
    return false unless event

    # Event-level permissions
    return true if user.is_event_admin?(event) || user.is_event_team_member?(event)

    # Exhibitors may view prizes to run the draw at their own event
    user.exhibitor? && user.is_event_vendor?(event)
  end

  # show? - event admins, team members, org admins
  def show?
    index?
  end

  # create? - event admins, org admins, and exhibitors adding their own event's prizes
  def create?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    event = resolve_event
    return false unless event

    # Event-level permissions
    return true if user.is_event_admin?(event)

    # Exhibitors may add/manage their own prizes to run the draw at their own event
    user.exhibitor? && user.is_event_vendor?(event)
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