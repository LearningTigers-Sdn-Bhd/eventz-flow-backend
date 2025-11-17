class VendorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :vendor, class_name: 'User', foreign_key: 'vendor_id'
  belongs_to :manager, class_name: 'User', foreign_key: 'manager_id', optional: true
  
  # Note: EventVendors are not directly dependent on VendorProfile deletion
  # They belong to events and vendors independently. This association is for querying only.
  has_many :event_vendors, ->(profile) { where(vendor_id: profile.vendor_id) }, class_name: 'EventVendor'

  # --- Validations ---
  validates :group_id, presence: true
  validates :vendor_id, presence: true
  validates :vendor_id, uniqueness: { scope: :group_id, message: 'already has a profile for this group' }
end
