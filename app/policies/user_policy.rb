# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  # Note: user = @current_user, record = the User instance being acted upon

  # Scope: Defines which records a user can see when fetching a collection (User.all)
  class Scope < Scope
    def resolve
      if user.org_owner? || user.organizer?
        # Org Owners and Organizers can see all users in the system
        scope.all 
      else
        # Standard members can only see themselves
        scope.where(id: user.id)
      end
    end
  end

  def index?
    # Org Owners and Organizers can list all users
    user.org_owner? || user.organizer?
  end

  def show?
    # 1. User can view their own profile (record == user).
    # 2. Org Owners/Organizers can view any profile.
    user.org_owner? || user.organizer? || record == user
  end

  def create?
    # Anyone can register a new user account (role is set to 'member' by model)
    record.new_record?
  end

  def update?
    # This policy authorizes regular profile updates (name, password).
    # Role updates are handled by a separate controller action and authorization.
    user.org_owner? || record == user
  end

  def destroy?
    # Only the highest authority can delete users.
    user.org_owner?
  end

  # NOTE: No explicit `update_role?` is needed here if the controller uses 
  # a separate `authorize_org_owner!` method, but a Pundit-style policy 
  # would define it like:
  # def update_role?
  #   user.org_owner?
  # end
end