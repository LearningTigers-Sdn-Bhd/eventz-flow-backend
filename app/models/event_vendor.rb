class EventVendor < ApplicationRecord
  # --- Associations ---
  belongs_to :event
  belongs_to :vendor, class_name: 'User', foreign_key: 'vendor_id'
  has_many :visitor_vendor_stamps, dependent: :destroy

  # --- Validations ---
  validates :event_id, presence: true
  validates :vendor_id, presence: true
  validates :vendor_id, uniqueness: { scope: :event_id, message: 'already exists for this event' }

  # --- STI Scopes ---
  scope :exhibitors, -> { where(type: 'Exhibitor') }
  scope :merchants, -> { where(type: 'Merchant') }

  # --- Class Methods ---
  def self.create_for_event(event, vendor, attributes = {})
    type = (event.use_ticket? || event.use_exhibitor_kit?) ? 'Exhibitor' : 'Merchant'
    create!(attributes.merge(event: event, vendor: vendor, type: type))
  end

  # --- Custom Associations / Methods ---
  def exhibitor_kit
    if is_a?(Exhibitor)
      super
    else
      nil
    end
  end
end

