# frozen_string_literal: true

# Platform-wide settings — org owner only, since these apply across every
# event on the platform, not just ones the user organizes.
class SystemSettingPolicy < ApplicationPolicy
  def show?
    user.present? && user.is_org_owner?
  end

  def update?
    show?
  end
end
