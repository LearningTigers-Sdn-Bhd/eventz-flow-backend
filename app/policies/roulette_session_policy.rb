class RouletteSessionPolicy < ApplicationPolicy
  # show? - org_owner/organizer/exhibitor, session owner and assigned users
  def show?
    return false if user.blank? || record.blank?

    # Global/org-level roles: org_owner & organizer (event_admins)
    return true if user.is_org_owner_or_organizer?

    # Exhibitors are explicitly allowed to access Prize Roulette
    return true if user.exhibitor?

    # Owner can view
    return true if record.user_id == user.id

    # Assigned users can view
    record.roulette_assigns.exists?(user_id: user.id)
  end

  # create? - any authenticated user can create their own sessions
  def create?
    return false if user.blank?
    true
  end

  # update? - org_owner/organizer or session owner
  def update?
    return false if user.blank? || record.blank?
    return true if user.is_org_owner_or_organizer?

    record.user_id == user.id
  end

  # destroy? - org_owner/organizer or session owner
  def destroy?
    update?
  end

  # background_manager? - org_owner/organizer or session owner
  def background_manager?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none if user.blank?

      # Org owners / organizers can see all sessions
      return scope.all if user.is_org_owner_or_organizer?

      # Exhibitors and regular users: sessions they own or are assigned to
      scope.left_joins(:roulette_assigns)
           .where('roulette_sessions.user_id = :uid OR roulette_assigns.user_id = :uid', uid: user.id)
           .distinct
    end
  end
end
