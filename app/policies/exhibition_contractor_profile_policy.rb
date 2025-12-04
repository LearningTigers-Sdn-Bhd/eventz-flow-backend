# app/policies/exhibition_contractor_profile_policy.rb
class ExhibitionContractorProfilePolicy < ApplicationPolicy
  def show?
    # Org owners and organizers can view any profile
    # Contractors can view their own profile
    user.org_owner? || user.organizer? || record.user_id == user.id
  end

  def update?
    # Org owners can update any profile
    # Organizers can update profiles of contractors they created
    # Contractors can update their own profile
    user.org_owner? ||
      (user.organizer? && record.user.created_by_id == user.id) ||
      record.user_id == user.id
  end
end
