class Event < ApplicationRecord
  belongs_to :user

  has_many :event_admins, dependent: :destroy
  has_many :admins, through: :event_admins, source: :user

  has_many :event_team_members, dependent: :destroy
  has_many :team_members, through: :event_team_members, source: :user
end
