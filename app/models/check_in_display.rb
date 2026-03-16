class CheckInDisplay < ApplicationRecord
  belongs_to :event
  belongs_to :active_plan, class_name: 'Plan', optional: true
  
  # Assets for Idle State
  has_one_attached :background_image, dependent: :purge_later
  has_one_attached :idle_video, dependent: :purge_later
  
  # Assets for Announcement State
  has_one_attached :announcement_image, dependent: :purge_later
  has_one_attached :announcement_video, dependent: :purge_later

  enum :animation_type, {
    fade_in: 0,
    slide_up: 1,
    zoom_in: 2,
    bounce: 3,
    typewriter: 4,
    no_animation: 5
  }, default: :fade_in, prefix: true

  enum :seating_plan_sidebar_position, {
    left: 0,
    right: 1
  }, default: :left, prefix: :sidebar

  # Script Presets - Using single quotes for lazy evaluation
  SCRIPT_TONES = {
    'neutral' => {
      'welcome_text' => 'Welcome',
      'seating_template' => 'Welcome, #{name}. You are at #{table_label}.'
    },
    'happy' => {
      'welcome_text' => "We're so glad you're here!",
      'seating_template' => "We're so thrilled to have you here, \#{name}! You are at \#{table_label}. Enjoy the event!"
    },
    'formal' => {
      'welcome_text' => 'Welcome',
      'seating_template' => 'Good evening #{name}. Your assigned seating is at #{table_label}. We wish you a pleasant evening.'
    },
    'warm' => {
      'welcome_text' => 'Welcome home',
      'seating_template' => 'It is wonderful to see you, #{name}. Please make yourself comfortable at #{table_label}.'
    }
  }.freeze

  validates :font_size, numericality: { greater_than: 0 }
  validates :idle_mode, inclusion: { in: %w[image video] }, allow_nil: true
  validates :announcement_mode, inclusion: { in: %w[image video] }, allow_nil: true
  validates :script_tone, inclusion: { in: SCRIPT_TONES.keys }, allow_nil: true

  def as_json_for_api(include_event: false)
    data = {
      id: id,
      event_id: event_id,
      font_family: font_family,
      font_size: font_size,
      animation_type: animation_type,
      is_bold: is_bold,
      name_color: name_color,
      voice_enabled: voice_enabled,
      voice_type: voice_type,
      welcome_text: welcome_text,
      script_tone: script_tone || 'neutral',
      
      # Modes
      idle_mode: idle_mode || 'image',
      announcement_mode: announcement_mode || 'image',
      announcement_duration: announcement_duration || 5000,

      # Seating Plan
      show_seating_plan: show_seating_plan,
      seating_plan_sidebar_position: seating_plan_sidebar_position,
      seating_plan_duration: seating_plan_duration || 8000,
      active_plan_id: active_plan_id,
      seating_announcement_template: seating_announcement_template,
      elevenlabs_settings: elevenlabs_settings || {},
      voice_rules: self[:voice_rules] || [],
      
      # URLs
      background_image_url: background_image_url,
      idle_video_url: idle_video_url,
      announcement_image_url: announcement_image_url,
      announcement_video_url: announcement_video_url
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

  def idle_video_url
    return nil unless idle_video.attached?
    Rails.application.routes.url_helpers.rails_blob_url(idle_video, only_path: true)
  end

  def announcement_image_url
    return nil unless announcement_image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(announcement_image, only_path: true)
  end

  def announcement_video_url
    return nil unless announcement_video.attached?
    Rails.application.routes.url_helpers.rails_blob_url(announcement_video, only_path: true)
  end
end
