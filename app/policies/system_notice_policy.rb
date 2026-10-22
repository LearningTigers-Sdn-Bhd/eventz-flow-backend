class SystemNoticePolicy < ApplicationPolicy
  # The banner reaches every user of every org, so only org owners may edit it.
  def show?
    user.org_owner?
  end

  def update?
    user.org_owner?
  end
end
