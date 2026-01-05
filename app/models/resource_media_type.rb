# app/models/resource_media_type.rb
class ResourceMediaType < ApplicationRecord
  has_many :resources

  validates :name, presence: true

  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end
end
