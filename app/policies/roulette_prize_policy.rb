class RoulettePrizePolicy < ApplicationPolicy
  # All prize actions are authorized through the session
  # This policy exists for consistency but delegates to session policy

  def show?
    return false if user.blank? || record.blank?
    RouletteSessionPolicy.new(user, record.roulette_session).show?
  end

  def create?
    return false if user.blank? || record.blank?
    RouletteSessionPolicy.new(user, record.roulette_session).update?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope < Scope
    def resolve
      if user.blank?
        scope.none
      else
        # Only show prizes for sessions user can access
        session_scope = RouletteSessionPolicy::Scope.new(user, RouletteSession).resolve
        scope.where(roulette_session_id: session_scope.select(:id))
      end
    end
  end
end
