class EventSponsorshipItem < ApplicationRecord
  # --- Associations ---
  belongs_to :event_sponsorship

  # --- Enums ---
  enum :item_type, { monetary: 0, in_kind: 1 }

  # --- Validations ---
  validates :title, presence: true
end
