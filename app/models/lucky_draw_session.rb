class LuckyDrawSession < ApplicationRecord
  # --- Associations ---
  belongs_to :event
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :gifts, dependent: :destroy
  has_many :invalid_participants, dependent: :destroy
  has_many :lucky_draw_entries, dependent: :destroy

  # --- Active Storage ---
  has_one_attached :logo, dependent: :purge_later
  has_one_attached :background_image, dependent: :purge_later

  # --- JSONB Attribute ---
  # draw_styles structure: { style: "wheel|slot|box", theme: "wireframe|colorful|cartoon" }

  # scanned_source: where "scanned" is read from when a day range is set
  #   ticket   - the ticket/visitor's first check-in (check_in_at)
  #   scan_log - any scan in the range (multi-scan events)
  #   entries  - only tickets scanned at the lucky draw booth (lucky_draw_entries)
  SCANNED_SOURCES = %w[ticket scan_log entries].freeze

  # gift_pick: how the next gift is chosen when gifts are on
  #   in_order - by gift order (default)
  #   random   - at random among the open gifts
  GIFT_PICKS = %w[in_order random].freeze

  # --- Validations ---
  validates :scanned_source, inclusion: { in: SCANNED_SOURCES }
  validates :gift_pick, inclusion: { in: GIFT_PICKS }
  validates :event_id, presence: true
  validates :title, presence: true
  validates :winners_per_draw, numericality: { only_integer: true, in: 1..200 }
  validate :validate_draw_styles_structure
  validate :validate_scanned_range
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

  # Round number for the next draw when gifts are off. Call inside #with_lock
  # so two simultaneous draws cannot share a round.
  def next_draw_round
    invalid_participants.maximum(:round).to_i + 1
  end

  # Same, for a gift sweep. Call inside #with_lock.
  def next_gift_round
    GiftWinner.where(gift_id: gifts.select(:id)).maximum(:round).to_i + 1
  end

  private

  def validate_scanned_range
    return unless scanned_from && scanned_to && scanned_from > scanned_to

    errors.add(:scanned_to, 'must be on or after scanned_from')
  end

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
