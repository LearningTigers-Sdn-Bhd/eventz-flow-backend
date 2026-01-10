# app/models/resource.rb
class Resource < ApplicationRecord
  belongs_to :user
  belongs_to :resource_topic
  belongs_to :resource_category
  belongs_to :resource_media_type, foreign_key: 'resource_media_type_id'

  has_one_attached :header_img

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  enum :status, { draft: 0, pending_review: 1, published: 2, rejected: 4 }
  # Alias in_review to pending_review for backward compatibility if any
  def in_review?
    pending_review?
  end

  scope :published, -> { where(status: :published) }

  default_scope { where(deleted_at: nil) }

  before_validation :generate_slug, on: :create

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
end
