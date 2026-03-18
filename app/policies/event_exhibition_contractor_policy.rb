class EventExhibitionContractorPolicy < ApplicationPolicy
  def index?
    exhibitor_management_enabled? && (user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.event))
  end

  def show?
    exhibitor_management_enabled? && (user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.event) || user.is_event_vendor?(record.event))
  end

  def create?
    exhibitor_management_enabled? && user.is_org_owner_or_organizer?
  end

  def destroy?
    exhibitor_management_enabled? && user.is_org_owner_or_organizer?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.is_org_owner_or_organizer?
      if user.is_exhibition_contractor? && user.exhibition_contractor_profile.present?
        return scope.where(exhibition_contractor_profile: user.exhibition_contractor_profile)
      end

      scope.none
    end
  end

  private

  def exhibitor_management_enabled?
    user.org_owner? || record.event.enable_exhibitor_management?
  end
end
