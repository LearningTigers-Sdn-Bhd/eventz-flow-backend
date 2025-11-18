class VendorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :vendor, class_name: 'User', foreign_key: 'vendor_id'
  
  # Note: EventVendors are not directly dependent on VendorProfile deletion
  # They belong to events and vendors independently. This association is for querying only.
  has_many :event_vendors, ->(profile) { where(vendor_id: profile.vendor_id) }, class_name: 'EventVendor'

  # --- Validations ---
  validates :vendor_id, presence: true, uniqueness: { message: 'already has a profile' }
  
  # --- Callbacks ---
  validate :vendor_must_have_vendor_role
  
  private
  
  def vendor_must_have_vendor_role
    if vendor.present? && !vendor.vendor?
      errors.add(:vendor, 'must have vendor role')
    end
  end
end
