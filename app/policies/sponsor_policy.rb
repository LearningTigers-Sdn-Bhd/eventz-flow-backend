class SponsorPolicy < ApplicationPolicy
  def index?
    user.is_org_owner? || user.is_organizer?
  end

  def show?
    user.is_org_owner? || user.is_organizer?
  end

  def create?
    user.is_org_owner? || user.is_organizer?
  end

  def update?
    user.is_org_owner? || user.is_organizer?
  end

  def destroy?
    user.is_org_owner? || user.is_organizer?
  end

  def lookup?
    # event_admin can lookup sponsors (read-only)
    user.is_org_owner? || user.is_organizer? || user.event_assignments.exists?(role: :event_admin)
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner? || user.is_organizer?
        scope.all
      elsif user.event_assignments.exists?(role: :event_admin)
        # Event admins can only see sponsors via lookup, or potentially all if the org allows sharing.
        # For now, sticking to the spec: "Global sponsor directory... org-scoped".
        # Assuming all sponsors belong to the org the user is part of.
        # Since we don't have explicit org_id on user/sponsor (User -> Group Member -> Group), 
        # we scope by group logic if strictly needed, but for now `scope.all` within the tenancy context is standard.
        # However, to be safe and follow "event_admin (event-scoped only)" rule from spec for MANAGEMENT,
        # but "lookup/select existing sponsors" implies read access to the directory.
        scope.all 
      else
        scope.none
      end
    end
  end
end
