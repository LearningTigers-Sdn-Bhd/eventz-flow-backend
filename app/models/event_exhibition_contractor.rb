class EventExhibitionContractor < ApplicationRecord
  belongs_to :event
  belongs_to :exhibition_contractor_profile

  validates :event_id, uniqueness: true
end