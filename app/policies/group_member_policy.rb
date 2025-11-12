class GroupMemberPolicy < ApplicationPolicy
  # All actions require org_owner or group manager access
  def index?
    authorized?
  end

  def show?
    authorized?
  end

  def create?
    authorized?
  end

  def update?
    authorized?
  end

  def destroy?
    authorized?
  end

  private

  def authorized?
    return false if user.blank?

    # Org owner can manage all group members
    return true if user.is_org_owner?

    # Get the group from the record
    group = if record.is_a?(GroupMember)
              record.group
            elsif record.respond_to?(:group)
              record.group
            else
              nil
            end

    return false if group.blank?

    # Group managers can manage members of their groups
    user.is_group_manager?(group)
  end
end
