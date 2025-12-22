class RentableItem < ApplicationRecord
  belongs_to :item_category
  belongs_to :user

  # --- Active Storage ---
  has_one_attached :image, dependent: :purge_later

  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true
  validates :unit_of_measure, presence: true
  validates :default_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validate :acceptable_image

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
