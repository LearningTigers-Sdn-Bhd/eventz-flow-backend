class RouletteAssignPolicy < ApplicationPolicy
  # create? - session owner can assign users
  def create?
    return false if user.blank? || record.blank?
    record.roulette_session.user_id == user.id
  end

  # destroy? - session owner can remove assignments
  def destroy?
    create?
  end

  class Scope < Scope
    def resolve
      if user.blank?
        scope.none
      else
        # Only show assigns for sessions owned by user
        scope.joins(:roulette_session).where(roulette_sessions: { user_id: user.id })
      end
    end
  end
end
