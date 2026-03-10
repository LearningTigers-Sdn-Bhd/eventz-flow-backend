class CheckInDisplay < ApplicationRecord
  belongs_to :event
  has_one_attached :background_image, dependent: :purge_later

  enum :animation_type, {
    fade_in: 0,
    slide_up: 1,
    zoom_in: 2,
    bounce: 3,
    typewriter: 4,
    no_animation: 5
  }, default: :fade_in

  validates :font_size, numericality: { greater_than: 0 }

  validate :acceptable_background_image

  def as_json_for_api(include_event: false)
    data = {
      id: id,
      event_id: event_id,
      font_family: font_family,
      font_size: font_size,
      animation_type: animation_type,
      is_bold: is_bold,
      name_color: name_color,
      background_image_url: background_image_url,
      voice_enabled: voice_enabled,
      voice_type: voice_type,
      welcome_text: welcome_text
    }

    if include_event && event.present?
      data[:event] = {
        id: event.id,
        title: event.title,
        slug: event.slug
      }
    else
      data[:created_at] = created_at&.iso8601
      data[:updated_at] = updated_at&.iso8601
    end

    data
  end

  def background_image_url
    return nil unless background_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(background_image, only_path: true)
  end

  private

  def acceptable_background_image
    return unless background_image.attached?

    unless background_image.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:background_image, 'must be a JPEG, PNG, GIF, or WebP')
    end

    if background_image.blob.byte_size > 10.megabytes
      errors.add(:background_image, 'is too large (max 10MB)')
    end
  end
end
