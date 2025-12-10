class LuckyDrawSession < ApplicationRecord
  # --- Associations ---
  belongs_to :event
  has_many :gifts, dependent: :destroy
  has_many :invalid_participants, dependent: :destroy

  # --- JSONB Attribute ---
  # draw_styles structure: { style: "wheel|slot|box", theme: "wireframe|colorful|cartoon" }

  # --- Validations ---
  validates :event_id, presence: true
  validates :title, presence: true
  validate :validate_draw_styles_structure

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
