class VendorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :vendor, class_name: 'User', foreign_key: 'vendor_id'

  # Note: EventVendors are not directly dependent on VendorProfile deletion
  # They belong to events and vendors independently. This association is for querying only.
  has_many :event_vendors, ->(profile) { where(vendor_id: profile.vendor_id) }, class_name: 'EventVendor'

  # --- Active Storage ---
  # Auto-purge image when profile is destroyed (uses background job)
  has_one_attached :image, dependent: :purge_later

  # --- Validations ---
  validates :vendor_id, presence: true, uniqueness: { message: 'already has a profile' }
  validate :vendor_must_have_vendor_role
  validate :acceptable_image

  private

  def vendor_must_have_vendor_role
    if vendor.present? && !vendor.vendor?
      errors.add(:vendor, 'must have vendor role')
    end
  end

  def acceptable_image
    return unless image.attached?

    unless image.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:image, 'must be a JPEG, PNG, GIF, or WebP')
    end

    if image.blob.byte_size > 5.megabytes
      errors.add(:image, 'is too large (max 5MB)')
    end
  end
end
