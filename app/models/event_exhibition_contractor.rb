class EventExhibitionContractor < ApplicationRecord
  # --- Associations ---
  belongs_to :event
  belongs_to :exhibition_contractor_profile

  # --- Validations ---
  validates :event_id, uniqueness: { message: "can only have one exhibition contractor assigned to it" }
end
