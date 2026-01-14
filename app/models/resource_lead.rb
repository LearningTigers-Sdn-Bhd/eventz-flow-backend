# app/models/resource_lead.rb
class ResourceLead < ApplicationRecord
  belongs_to :resource

  validates :email, presence: true
end
