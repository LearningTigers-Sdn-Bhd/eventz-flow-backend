# app/models/resource_write_permission.rb
class ResourceWritePermission < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true

  enum :status, { base: 0, partnership: 1 }
end
