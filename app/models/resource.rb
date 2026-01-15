# app/models/resource.rb

class Resource < ApplicationRecord
  belongs_to :user
  belongs_to :resource_topic
  belongs_to :resource_category
  belongs_to :resource_media_type, foreign_key: 'resource_media_type_id'
  has_many :resource_changelogs, dependent: :destroy
  has_many :resource_leads, dependent: :destroy

  # Check if vips is available before defining variants
  # Variants are only useful if we can process them with vips
  begin
    require 'vips'
    VIPS_AVAILABLE = true
  rescue LoadError
    VIPS_AVAILABLE = false
    Rails.logger.warn "Vips library not available - image variants will not be defined"
  end

  has_one_attached :header_img do |attachable|
    next unless VIPS_AVAILABLE

    # Optimized variants with WebP conversion and metadata stripping
    attachable.variant :thumbnail,
      resize_to_limit: [300, 200],
      format: :webp,
      saver: { quality: 85, strip: true }

    attachable.variant :medium,
      resize_to_limit: [800, 533],
      format: :webp,
      saver: { quality: 85, strip: true }

    attachable.variant :large,
      resize_to_limit: [1600, 1067],
      format: :webp,
      saver: { quality: 90, strip: true }
  end

  # Attribute to store the current user for changelog tracking
  attr_accessor :current_user_for_changelog
  attr_accessor :_skip_header_img_validation

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :determine_if_header_img_changed

  # Image validations - skip if header_img hasn't changed on update
  validate :header_img_format, if: -> { header_img.attached? && !_skip_header_img_validation }
  validate :header_img_size, if: -> { header_img.attached? && !_skip_header_img_validation }
  validate :header_img_dimensions, if: -> { header_img.attached? && !_skip_header_img_validation }

  enum :status, { draft: 0, pending_review: 1, published: 2, rejected: 4 }
  # Alias in_review to pending_review for backward compatibility if any
  def in_review?
    pending_review?
  end

  scope :published, -> { where(status: :published) }
  scope :search, ->(query) {
    where("resources.title ILIKE :q OR resources.meta_description ILIKE :q", q: "%#{query}%")
  }
  scope :featured, -> { where(priority: 1) }
  scope :standard, -> { where(priority: 2..5) }

  default_scope { where(deleted_at: nil) }

  before_validation :generate_slug, on: :create
  after_update :create_changelog_entry, if: :should_create_changelog?

  def self.accessible_by_writer(user)
    # Only show non-deleted records by default
    published_ids = where(status: :published).pluck(:id)
    own_ids = where(user: user).pluck(:id)
    all_ids = (published_ids + own_ids).uniq

    where(id: all_ids)
            .includes(:resource_topic, :resource_category, :resource_media_type)
            .order(status: :asc, updated_at: :desc)
  end

  def self.admin_dashboard_view
    # default_scope handles deleted_at: nil
    all.includes(:user, :resource_topic, :resource_category, :resource_media_type)
       .order(created_at: :desc)
  end

  def self.pending_review_queue
    where(status: :pending_review)
            .includes(:user, :resource_topic, :resource_category, :resource_media_type, user: :resource_write_permission)
            .order(created_at: :desc)
  end

  def self.public_feed
    published.includes(:user, :resource_topic, :resource_category, :resource_media_type)
             .order(published_at: :desc, created_at: :desc)
  end

  def self.featured_page_resources
    {
      featured: public_feed.featured.limit(3),
      standard: public_feed.standard.limit(6)
    }
  end

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  private

  def generate_slug
    return if slug.present?
    self.slug = title.to_s.parameterize
  end

  def determine_if_header_img_changed
    # Default: don't skip validation (validate by default)
    self._skip_header_img_validation = false

    return unless persisted? && header_img.attached?

    # For existing records, try to determine if this is a new upload or existing attachment
    begin
      current_blob_id = header_img.blob.id
      return unless current_blob_id # Can't check if blob has no ID

      # Check if this blob is already attached to this record in the database
      # If it is, this is the existing image and we should skip validation
      existing_attachment = ActiveStorage::Attachment.find_by(
        record_type: 'Resource',
        record_id: id,
        name: 'header_img'
      )

      if existing_attachment && existing_attachment.blob_id == current_blob_id
        # This blob is already attached - it's the existing image, skip validation
        self._skip_header_img_validation = true
      end
      # If no existing attachment or different blob_id, it's a new upload - validate it
    rescue => e
      # If we can't determine, validate to be safe
      Rails.logger.warn "Could not determine if header_img changed: #{e.message}"
      self._skip_header_img_validation = false
    end
  end

  def header_img_format
    acceptable_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
    unless acceptable_types.include?(header_img.content_type)
      errors.add(:header_img, 'must be a JPEG, PNG, or WebP image')
    end
  end

  def header_img_size
    # 10MB limit
    max_size = 10.megabytes
    if header_img.byte_size > max_size
      errors.add(:header_img, "size must be less than #{max_size / 1.megabyte}MB")
    end
  end

  def header_img_dimensions
    # Skip validation if blob is not persisted yet (will be validated on save)
    return unless header_img.blob.persisted?

    begin
      require 'vips'
    rescue LoadError => e
      # Vips library not available - skip dimension validation
      Rails.logger.warn "Vips library not available, skipping dimension validation: #{e.message}"
      return
    end

    begin
      # Download and check dimensions using Vips
      header_img.blob.open do |file|
        image = ::Vips::Image.new_from_file(file.path)

        max_width = 4000
        max_height = 4000

        if image.width > max_width || image.height > max_height
          errors.add(:header_img, "dimensions must be less than #{max_width}x#{max_height}px (current: #{image.width}x#{image.height}px)")
        end
      end
    rescue ::Vips::Error => e
      errors.add(:header_img, "could not be processed - invalid image format")
    rescue ActiveStorage::FileNotFoundError, Errno::ENOENT => e
      # Blob file not yet available on disk - skip validation (will validate on save)
      Rails.logger.debug "Blob file not yet available for validation: #{e.message}"
      return
    rescue => e
      errors.add(:header_img, "could not be validated: #{e.message}")
    end
  end

  def should_create_changelog?
    # Only create changelog if the resource was published before this update
    # and we have a user to attribute the change to
    return false unless current_user_for_changelog.present?

    # Check if the resource was published before the update
    # Use status_before_last_save or check if current status is published
    # and it wasn't just changed from another status to published
    if saved_change_to_status?
      # Status changed - check the old value
      old_status, new_status = saved_change_to_status
      return old_status == 'published' || old_status == 2
    else
      # Status didn't change - check current status
      return published?
    end
  end

  def create_changelog_entry
    # Get the previous values before the update
    changelog_attrs = {
      resource_id: id,
      changed_by_user_id: current_user_for_changelog.id,
      changed_at: Time.current
    }

    # Capture all the fields as they were BEFORE the update
    # Use saved_changes or _before_last_save methods
    changelog_attrs[:title] = saved_change_to_title? ? saved_change_to_title[0] : title
    changelog_attrs[:article] = saved_change_to_article? ? saved_change_to_article[0] : article
    changelog_attrs[:slug] = saved_change_to_slug? ? saved_change_to_slug[0] : slug
    changelog_attrs[:meta_description] = saved_change_to_meta_description? ? saved_change_to_meta_description[0] : meta_description
    changelog_attrs[:resource_topic_id] = saved_change_to_resource_topic_id? ? saved_change_to_resource_topic_id[0] : resource_topic_id
    changelog_attrs[:resource_category_id] = saved_change_to_resource_category_id? ? saved_change_to_resource_category_id[0] : resource_category_id
    changelog_attrs[:resource_media_type_id] = saved_change_to_resource_media_type_id? ? saved_change_to_resource_media_type_id[0] : resource_media_type_id
    # For status, convert the old value to integer if it was changed
    if saved_change_to_status?
      old_status = saved_change_to_status[0]
      changelog_attrs[:status] = old_status.is_a?(String) ? Resource.statuses[old_status] : old_status
    else
      changelog_attrs[:status] = Resource.statuses[status]
    end
    changelog_attrs[:published_at] = saved_change_to_published_at? ? saved_change_to_published_at[0] : published_at
    changelog_attrs[:view_counts] = saved_change_to_view_counts? ? saved_change_to_view_counts[0] : view_counts
    changelog_attrs[:priority] = saved_change_to_priority? ? saved_change_to_priority[0] : priority
    changelog_attrs[:is_gated] = saved_change_to_is_gated? ? saved_change_to_is_gated[0] : is_gated
    changelog_attrs[:is_official] = saved_change_to_is_official? ? saved_change_to_is_official[0] : is_official
    changelog_attrs[:rejection_reason] = saved_change_to_rejection_reason? ? saved_change_to_rejection_reason[0] : rejection_reason

    ResourceChangelog.create!(changelog_attrs)
  end
end
