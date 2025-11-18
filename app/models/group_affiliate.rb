class GroupAffiliate < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :vendor, class_name: 'User'

  # --- Validations ---
  validates :vendor_id, uniqueness: { scope: :group_id, message: 'is already asssigned to this group' }
  validate :vendor_must_have_vendor_role

  private

  def vendor_must_have_vendor_role
    if vendor.present? && !vendor.vendor?
      errors.add(:vendor, 'must have vendor role')
    end
  end
end
