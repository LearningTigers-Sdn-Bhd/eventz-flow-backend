class EventSponsorshipTierPolicy < ApplicationPolicy
  def index?
    allowed?
  end

  def show?
    allowed?
  end

  def create?
    allowed?
  end

  def update?
    allowed?
  end

  def destroy?
    allowed?
  end

  private

  def allowed?
    return false unless user && record
    # record is the tier instance or class? If instance, check event access.
    # If checking class level (e.g. index?), typically record is just the class, 
    # but here we usually pass a context or check generalized permissions.
    # For simplicity, assuming instance checks or scoped checks handled in controller.
    
    event = record.is_a?(EventSponsorshipTier) ? record.event : nil
    
    if event
      user.is_org_owner? || user.is_organizer? || user.is_event_admin?(event)
    else
      # Fallback for class-level checks if needed, though usually handled via Scope
      user.is_org_owner? || user.is_organizer? || user.event_assignments.exists?(role: :event_admin)
    end
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner? || user.is_organizer?
        scope.all
      else
        # Event admins see tiers for their assigned events
        assigned_event_ids = user.event_assignments.where(role: :event_admin).pluck(:event_id)
        scope.where(event_id: assigned_event_ids)
      end
    end
  end
end
