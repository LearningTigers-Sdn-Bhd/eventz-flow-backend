class GiftWinnerPolicy < ApplicationPolicy
  # Convenience method for delegating to the parent resource policy
  def event_policy
    return nil if record.blank? || !record.respond_to?(:gift)

    gift = record.gift
    return nil unless gift.respond_to?(:event)

    Pundit.policy(user, gift.event)
  rescue NoMethodError
    nil
  end

  # create? - event admins, team members, org admins, and exhibitors running their own event's draw
  def create?
    return false if user.blank? || record.blank?

    # Organization-level permissions
    return true if user.is_org_owner? || user.is_organizer?

    gift = record.respond_to?(:gift) ? record.gift : nil
    return false unless gift&.event

    # Event-level permissions
    return true if user.is_event_admin?(gift.event) || user.is_event_team_member?(gift.event)

    # Exhibitors may record winners drawn from their own captured leads
    user.exhibitor? && user.is_event_vendor?(gift.event)
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
