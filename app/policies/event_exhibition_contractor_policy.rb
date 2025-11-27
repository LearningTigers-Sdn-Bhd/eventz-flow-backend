class EventExhibitionContractorPolicy < ApplicationPolicy
  def index?
    user.org_owner? || user.organizer? || (user.exhibition_contractor? && record.event.present?)
  end

  def create?
    user.org_owner? || user.organizer?
  end

  def destroy?
    user.org_owner? || user.organizer?
  end

  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        scope.all
      elsif user.exhibition_contractor?
        # Exhibition contractors can only see their own assigned events
        scope.joins(:exhibition_contractor_profile).where(exhibition_contractor_profiles: { user_id: user.id })
      else
        scope.none
      end
    end
  end
end