class WishWallSetting < ApplicationRecord
  self.table_name = 'event_wish_wall_settings'

  belongs_to :event
  has_one_attached :background_image, dependent: :purge_later

  validates :event_id, uniqueness: true, on: :create
  validates :display_mode, inclusion: { in: %w[cards animation] }
  validates :animation_shape, inclusion: { in: %w[heart names infinity butterfly] }, allow_nil: true
  validate :acceptable_background_image

  private

  def acceptable_background_image
    return unless background_image.attached?

    unless background_image.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:background_image, 'must be a JPEG, PNG, GIF, or WebP')
    end

    return unless background_image.blob.byte_size > 10.megabytes

    errors.add(:background_image, 'is too large (max 10MB)')
  end
end
