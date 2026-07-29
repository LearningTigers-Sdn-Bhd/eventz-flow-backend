class Exhibitor < EventVendor
  has_many :exhibitor_kits, -> { order(:created_at, :id) }, dependent: :destroy,
    foreign_key: :event_vendor_id, inverse_of: :event_vendor
  has_many :exhibitor_team_members, through: :exhibitor_kits
  accepts_nested_attributes_for :exhibitor_kits, allow_destroy: true

  def legacy_exhibitor_kit
    exhibitor_kits.first
  end
end
