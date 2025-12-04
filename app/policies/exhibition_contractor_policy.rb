# app/policies/exhibition_contractor_policy.rb
class ExhibitionContractorPolicy < UserPolicy
  # Note: user = @current_user, record = the User instance with exhibition_contractor role

  def index?
    user.organizer? || user.org_owner?
  end

  def show?
    user.org_owner? || user.organizer? || record == user
  end

  def create?
    user.organizer? || user.org_owner?
  end

  def update?
    # Org owners can update any contractor
    # Organizers can update contractors they created
    # Contractors can update their own account
    user.org_owner? || (user.organizer? && record.created_by_id == user.id) || record == user
  end

  def toggle_status?
    user.org_owner? || (user.organizer? && record.created_by_id == user.id)
  end

  def destroy?
    user.org_owner? || (user.organizer? && record.created_by_id == user.id)
  end
end
