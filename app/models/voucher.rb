class Voucher < ApplicationRecord
  # --- Associations ---
  belongs_to :vendor, class_name: "User", foreign_key: "vendor_id"
  belongs_to :event

  # Permanent delete (org owner only) removes the redemption history with it.
  has_many :voucher_redemption_logs, dependent: :destroy
  has_many :voucher_usages, dependent: :destroy

  # --- Active Storage ---
  # Auto-purge image when voucher is destroyed (uses background job)
  has_one_attached :image, dependent: :purge_later

  # --- Enums ---
  enum :status, { active: 0, inactive: 1 }

  enum :voucher_type, {
    fixed_amount: 0,
    percentage: 1,
    free_item: 2
  }

  # --- Soft Delete Scopes ---
  # Archived vouchers are hidden everywhere (index, showcase, redemption, stats).
  # Redemption logs/usages reach their voucher through `with_deleted`.
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  # --- Scopes ---
  scope :for_event, ->(event) { where(event: event) }

  # --- Validations ---
  validate :acceptable_image

  # --- Instance Methods ---
  def archive
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  # Check if voucher has remaining quota for redemption
  # Returns true if unlimited, or if redeemed count is less than total available
  def has_quota_remaining?
    return true if is_unlimited
    return true if total_redemption_available.to_i.zero?

    redeemed_count.to_i < total_redemption_available.to_i
  end

  private

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
