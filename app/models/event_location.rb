class EventLocation < ApplicationRecord
  # --- Associations ---
  # An event location belongs to a single event.
  # This matches the 'event_id' column in your schema.
  belongs_to :event, inverse_of: :event_locations

  # An event location can have multiple members assigned to staff that specific location
  # This matches the 'event_location_members' join table in your schema.
  # Note: The 'member' column in the join table likely refers to a User.
  has_many :event_location_members, dependent: :destroy
  has_many :members, through: :event_location_members, source: :member # Assuming the join model uses :member_id

  # --- Validations ---
  validates :name, presence: true
  validates :scan_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Enforce uniqueness for the combination of event_id and name, as per the database index
  validates :name, uniqueness: { scope: :event_id, message: "already exists for this event" }
  
  # --- Scopes ---
  scope :active, -> { where('scan_limit > 0') }

end