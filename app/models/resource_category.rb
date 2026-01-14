# app/models/resource_category.rb
class ResourceCategory < ApplicationRecord
  has_many :resources

  scope :order_by_published_resources, -> {
    count_expression = "COUNT(CASE WHEN resources.status = #{Resource.statuses[:published]} THEN 1 END)"
    left_joins(:resources)
      .select("resource_categories.*, #{count_expression} as published_resources_count")
      .group("resource_categories.id")
      .order(Arel.sql("#{count_expression} DESC"))
  }

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
