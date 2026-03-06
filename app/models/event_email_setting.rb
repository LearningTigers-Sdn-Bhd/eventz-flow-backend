class EventEmailSetting < ApplicationRecord
  belongs_to :event

  validates :event_id, uniqueness: true
end
