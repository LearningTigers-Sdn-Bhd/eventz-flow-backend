class CertificateTemplate < ApplicationRecord
  # --- Associations ---
  belongs_to :event

  # --- Active Storage ---
  # The uploaded, already-designed certificate background. Auto-purge on destroy.
  has_one_attached :background_image, dependent: :purge_later

  # --- Enums ---
  enum :status, { draft: 0, ready: 1, archived: 2 }

  # --- Constants ---
  ORIENTATIONS = %w[portrait landscape].freeze

  # --- Validations ---
  validates :orientation, inclusion: { in: ORIENTATIONS }
  validates :canvas_width, :canvas_height, numericality: { greater_than: 0 }
  validates :name, presence: true, length: { maximum: 100 }
  validate :fields_must_be_array
  validate :ticket_types_valid
  validate :single_default_template
  validate :ready_requires_completeness
  validate :acceptable_background_image

  before_validation { self.ticket_type_ids = Array(ticket_type_ids).map(&:to_i).uniq }

  # --- Instance Methods ---
  def background_image_url
    return nil unless background_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(background_image, only_path: true)
  end

  def as_json(options = {})
    super(options).merge("background_image_url" => background_image_url)
  end

  private

  def fields_must_be_array
    errors.add(:fields, "must be an array") unless fields.is_a?(Array)
  end

  # Ticket types must belong to this event and be claimed by one template only,
  # otherwise a ticket could resolve to two designs.
  def ticket_types_valid
    return if event.nil? || ticket_type_ids.empty?

    valid = event.ticket_types.where(id: ticket_type_ids).pluck(:id)
    errors.add(:ticket_type_ids, 'must belong to this event') if valid.size != ticket_type_ids.size

    taken = event.certificate_templates.where.not(id: id).pluck(:ticket_type_ids).flatten
    errors.add(:ticket_type_ids, 'are already used by another template') if (taken & ticket_type_ids).any?
  end

  def single_default_template
    return if event.nil? || ticket_type_ids.any?

    others = event.certificate_templates.where.not(id: id).where(ticket_type_ids: [])
    errors.add(:base, 'Only one template can apply to all other ticket types') if others.exists?
  end

  # A template can only be marked ready when it is actually sendable.
  def ready_requires_completeness
    return unless ready?

    errors.add(:status, "requires a background image") unless background_image.attached?
    errors.add(:status, "requires at least one field") unless fields.is_a?(Array) && fields.any?
  end

  def acceptable_background_image
    return unless background_image.attached?

    unless background_image.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:background_image, "must be a JPEG, PNG, or WebP")
    end

    if background_image.blob.byte_size > 10.megabytes
      errors.add(:background_image, "is too large (max 10MB)")
    end
  end
end
