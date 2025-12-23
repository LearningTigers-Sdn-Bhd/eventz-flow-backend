class BusinessHostAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validates :business_matching_event_id, presence: true
  # Ensure a user is assigned to a specific session only once
  validates :business_matching_event_id, uniqueness: { scope: [:user_id, :event_id], message: "is already assigned to this host" }
end
