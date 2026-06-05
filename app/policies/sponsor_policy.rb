class SponsorPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer?
  end

  def show?
    readable?
  end

  def create?
    user.org_owner? || user.organizer?
  end

  def update?
    manageable_record?
  end

  def destroy?
    manageable_record?
  end

  def lookup?
    user.org_owner? || user.organizer? || user.event_assignments.exists?(role: :event_admin)
  end

  class Scope < Scope
    def resolve
      if user.org_owner?
        scope.all
      elsif user.organizer?
        scope.where(created_by_id: user.id)
      elsif user.event_assignments.exists?(role: :event_admin)
        scope.joins(:event_sponsorships)
             .where(event_sponsorships: { event_id: user.event_assignments.where(role: :event_admin).select(:event_id) })
             .distinct
      else
        scope.none
      end
    end
  end

  private

  def readable?
    manageable_record? || event_admin_can_access_record?
  end

  def manageable_record?
    user.org_owner? || (user.organizer? && record.created_by_id == user.id)
  end

  def event_admin_can_access_record?
    return false unless record.is_a?(Sponsor)

    assigned_event_ids = user.event_assignments.where(role: :event_admin).select(:event_id)
    record.event_sponsorships.where(event_id: assigned_event_ids).exists?
  end
end
