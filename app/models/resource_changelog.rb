# app/models/resource_changelog.rb
class ResourceChangelog < ApplicationRecord
  belongs_to :resource
  belongs_to :changed_by_user, class_name: 'User', foreign_key: 'changed_by_user_id'

  # Optional associations to maintain referential integrity
  # Note: These are stored as IDs but we don't enforce foreign keys
  # to maintain historical data even if the referenced record is deleted

  validates :resource_id, presence: true
  validates :changed_by_user_id, presence: true
  validates :changed_at, presence: true

  # Scopes for querying
  scope :for_resource, ->(resource) { where(resource_id: resource.id) }
  scope :by_user, ->(user) { where(changed_by_user_id: user.id) }
  scope :recent, -> { order(changed_at: :desc) }
  scope :oldest_first, -> { order(changed_at: :asc) }

  # Default ordering: most recent first
  default_scope { order(changed_at: :desc) }

  # Helper method to get the changelog history for a specific resource
  def self.history_for(resource)
    unscoped.for_resource(resource).recent
  end

  # Returns a hash of the changes (snapshot of the resource at that point in time)
  def snapshot
    {
      title: title,
      article: article,
      slug: slug,
      meta_description: meta_description,
      resource_topic_id: resource_topic_id,
      resource_category_id: resource_category_id,
      resource_media_type_id: resource_media_type_id,
      status: status,
      published_at: published_at,
      view_counts: view_counts,
      priority: priority,
      is_gated: is_gated,
      is_official: is_official,
      rejection_reason: rejection_reason
    }
  end
end
