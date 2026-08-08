class EventAssignment < ApplicationRecord
  belongs_to :event
  belongs_to :user

  # Roles for this specific event
  enum :role, {
    event_admin: 'event_admin',
    event_team_member: 'event_team_member',
    business_host: 'business_host',
    business_matching_admin: 'business_matching_admin'
  }

  # An event assignment is unique by the user and the event
  validates :user_id, uniqueness: { scope: :event_id }
  validates :role, presence: true
end