class UserPolicy < ApplicationPolicy
  # Note: user = @current_user, record = the User instance being acted upon

  # Scope: Defines which records a user can see when fetching a collection (User.all)
  # Managers need to see all users to assign them as team members.
  class Scope < Scope
    def resolve
      if user.org_owner? || user.manager?
        # Org Owners and Managers can see all users in the system (to facilitate assignment)
        scope.all 
      else
        # Standard members can only see themselves
        scope.where(id: user.id)
      end
    end
  end

  def index?
    # Org Owners and Managers need to be able to list all users (for assignment purposes)
    user.org_owner? || user.manager?
  end

  def show?
    # 1. User can view their own profile (record == user).
    # 2. Org Owners can view any profile.
    # 3. Managers can view any profile (to look up users for team assignment).
    user.org_owner? || user.manager? || record == user
  end

  def create?
    # Anyone can register, but the controller/model ensures they are created as 'member'.
    # We rely on the model's `after_initialize` to set the role to 'member'.
    # This explicit check also ensures only a new record is authorized for creation.
    record.new_record? 
  end

  def update?
    # 1. A user can update their own profile (record == user).
    # 2. Org Owners can update any profile (e.g., changing another user's role).
    user.org_owner? || record == user
  end

  def destroy?
    # Only the highest authority can delete users.
    user.org_owner?
  end
end