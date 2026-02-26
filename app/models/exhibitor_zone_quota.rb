class ExhibitorZoneQuota < ApplicationRecord
  self.table_name = "exhibitor_zone_quotas"

  belongs_to :event
  has_many :exhibitor_booth_prices, dependent: :nullify

  validates :zone, presence: true, uniqueness: { scope: :event_id }
  validates :quota, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
