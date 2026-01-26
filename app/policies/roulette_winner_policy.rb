class RouletteWinnerPolicy < ApplicationPolicy
  # show? - session owner and assigned users can view winners
  def show?
    return false if user.blank? || record.blank?
    RouletteSessionPolicy.new(user, record.roulette_session).show?
  end

  # create? - org_owner/organizer, session owner and assigned users can create winners
  def create?
    return false if user.blank? || record.blank?
    session = record.roulette_session

    # Org owners / organizers (includes event_admin-style users) can always create
    return true if user.is_org_owner_or_organizer?

    # Session owner
    return true if session.user_id == user.id

    # Assigned users (including exhibitors assigned to the session)
    session.roulette_assigns.exists?(user_id: user.id)
  end

  # destroy? - same permissions as create?
  def destroy?
    create?
  end

  # notify? - same permissions as create?
  def notify?
    create?
  end

  class Scope < Scope
    def resolve
      if user.blank?
        scope.none
      else
        # Only show winners for sessions user can access
        session_scope = RouletteSessionPolicy::Scope.new(user, RouletteSession).resolve
        scope.where(roulette_session_id: session_scope.select(:id))
      end
    end
  end
end
