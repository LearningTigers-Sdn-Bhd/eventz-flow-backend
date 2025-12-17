class LuckyDrawSession < ApplicationRecord
  # --- Associations ---
  belongs_to :event
  has_many :gifts, dependent: :destroy
  has_many :invalid_participants, dependent: :destroy

  # --- Active Storage ---
  has_one_attached :logo, dependent: :purge_later
  has_one_attached :background_image, dependent: :purge_later

  # --- JSONB Attribute ---
  # draw_styles structure: { style: "wheel|slot|box", theme: "wireframe|colorful|cartoon" }

  # --- Validations ---
  validates :event_id, presence: true
  validates :title, presence: true
  validate :validate_draw_styles_structure
  validate :acceptable_logo
  validate :acceptable_background_image

  # --- Scopes ---
  scope :ordered, -> { order(draw_date: :asc, created_at: :asc) }

  # --- Helper Methods ---
  def draw_style
    draw_styles&.dig('style')
  end

  def draw_theme
    draw_styles&.dig('theme') || 'wireframe'
  end

  private

  def acceptable_logo
    return unless logo.attached?

    unless logo.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:logo, 'must be a JPEG, PNG, GIF, or WebP')
    end

    if logo.blob.byte_size > 5.megabytes
      errors.add(:logo, 'is too large (max 5MB)')
    end
  end

  def acceptable_background_image
    return unless background_image.attached?

    unless background_image.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:background_image, 'must be a JPEG, PNG, GIF, or WebP')
    end

    if background_image.blob.byte_size > 10.megabytes
      errors.add(:background_image, 'is too large (max 10MB)')
    end
  end

  def validate_draw_styles_structure
    return if draw_styles.blank?

    unless draw_styles.is_a?(Hash)
      errors.add(:draw_styles, 'must be a hash')
      return
    end

    style = draw_styles['style']
    theme = draw_styles['theme']

    valid_styles = %w[wheel slot box]
    valid_themes = %w[wireframe colorful cartoon]

    unless style.present? && valid_styles.include?(style)
      errors.add(:draw_styles, "style must be one of: #{valid_styles.join(', ')}")
    end

    if theme.present? && !valid_themes.include?(theme)
      errors.add(:draw_styles, "theme must be one of: #{valid_themes.join(', ')}")
    end
  end
end
