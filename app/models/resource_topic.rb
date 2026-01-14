# app/models/resource_topic.rb
class ResourceTopic < ApplicationRecord
  has_many :resources

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

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
    self.slug = name.to_s.parameterize
  end
end
