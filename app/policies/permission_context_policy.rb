# app/policies/permission_context_policy.rb
class PermissionContextPolicy < ApplicationPolicy
  # Any authenticated user can check the permission context.
  def show?
    user.present?
  end
end
