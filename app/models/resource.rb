# app/models/resource.rb
class Resource < ApplicationRecord
  belongs_to :user
  belongs_to :resource_topic
  belongs_to :resource_category
  belongs_to :resource_media_type, foreign_key: 'resource_media_type_id'


  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  enum :status, { draft: 0, in_review: 1, published: 2 }

  default_scope { where(deleted_at: nil) }

  before_validation :generate_slug, on: :create

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
