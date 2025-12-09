class EventRentableItemPriceTierPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record&.event_rentable_item&.event && user.exhibition_contractor_for?(record.event_rentable_item.event)) || (record&.event_rentable_item&.event && user.is_event_staff?(record.event_rentable_item.event))
  end

  def show?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record&.event_rentable_item&.event && user.exhibition_contractor_for?(record.event_rentable_item.event)) || (record&.event_rentable_item&.event && user.is_event_staff?(record.event_rentable_item.event))
  end

  def create?
    user.org_owner? || user.organizer? || (record&.event_rentable_item&.event && user.is_event_staff?(record.event_rentable_item.event))
  end

  def update?
    user.org_owner? || user.organizer? || (record&.event_rentable_item&.event && user.is_event_staff?(record.event_rentable_item.event))
  end

  def destroy?
    user.org_owner? || user.organizer? || (record&.event_rentable_item&.event && user.is_event_staff?(record.event_rentable_item.event))
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor? && user.exhibition_contractor_profile.present?
        scope.joins(event_rentable_item: { event: :event_exhibition_contractors })
             .where(event_exhibition_contractors: { exhibition_contractor_profile_id: user.exhibition_contractor_profile.id })
      elsif user.assigned_events.present? && user.is_staff?
        scope.joins(event_rentable_item: { event: :event_assignments })
             .where(event_assignments: { user_id: user.id, role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]] })
      else
        scope.none
      end
    end
  end
end
