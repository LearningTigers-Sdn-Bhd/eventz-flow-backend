class GroupAffiliate < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :vendor, class_name: 'User'

  # --- Validations ---
  validates :vendor_id, uniqueness: { scope: :group_id, message: 'is already asssigned to this group' }
  validate :vendor_must_have_vendor_role

  # --- Callbacks ---
  after_create :create_vendor_profile_if_vendor

  private

  def vendor_must_have_vendor_role
    if vendor.present? && !vendor.vendor?
      errors.add(:vendor, 'must have vendor role')
    end
  end

  def create_vendor_profile_if_vendor
    return unless vendor.vendor?

    vendor_profile = VendorProfile.find_or_initialize_by(group: group, vendor: vendor)

    # Set manager_id from existing vendor profiles if not set
    if vendor_profile.manager_id.nil?
      existing_profile = VendorProfile.where(vendor: vendor).where.not(manager_id: nil).first
      vendor_profile.manager_id = existing_profile&.manager_id
    end

    vendor_profile.save
  end
end
