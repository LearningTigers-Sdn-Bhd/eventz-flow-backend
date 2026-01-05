# app/models/resource_lead.rb
class ResourceLead < ApplicationRecord
  # Eventually, this could belong_to a resource if we add the foreign key.
  # belongs_to :resource

  validates :email, presence: true
end
