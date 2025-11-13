class GroupMember < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :user

  # --- Validations ---
  validates :user_id, uniqueness: { scope: :group_id }
  validate :user_cannot_be_org_owner
  validate :user_must_be_manager_or_member

  # --- Methods ---
  def manager?
    has_manager_access?
  end

  private

  def user_cannot_be_org_owner
    if user&.org_owner?
      errors.add(:user, 'cannot be an org_owner')
    end
  end

  def user_must_be_manager_or_member
    if user.present? && !user.manager? && !user.member?
      errors.add(:user, 'must be a manager or member')
    end
  end
end
