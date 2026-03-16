class ClonedVoicePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.org_owner? || (record.event_id && user.is_event_staff?(record.event))
  end

  def create?
    user.org_owner? || user.organizer? || (record.event_id && user.is_event_admin?(record.event))
  end

  def update?
    user.org_owner? || record.owner_id == user.id || (record.event_id && user.is_event_admin?(record.event) && record.creator_id == user.id)
  end

  def destroy?
    user.org_owner? || record.owner_id == user.id || (record.event_id && user.is_event_admin?(record.event) && record.creator_id == user.id)
  end

  class Scope < Scope
    def resolve
      if user.org_owner?
        scope.all
      else
        # See voices they own OR tied to events they manage
        event_ids = user.event_assignments.where(role: [:event_admin, :event_team_member]).pluck(:event_id)
        scope.where(event_id: event_ids).or(scope.where(owner_id: user.id))
      end
    end
  end
end
