class Exhibitor < EventVendor
  has_one :exhibitor_kit, dependent: :destroy, foreign_key: :event_vendor_id, inverse_of: :event_vendor
  has_many :exhibitor_team_members, through: :exhibitor_kit
  accepts_nested_attributes_for :exhibitor_kit, allow_destroy: true

  validates :exhibitor_kit, presence: true, if: -> { Rails.env.production? }
end