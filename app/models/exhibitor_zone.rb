class ExhibitorZone < ApplicationRecord
  self.table_name = 'exhibitor_zones'

  belongs_to :event
  has_many :exhibitor_booth_prices, dependent: :nullify

  validates :zone, presence: true, uniqueness: { scope: :event_id }
  validates :quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :quota_must_cover_booth_price_quotas

  private

  def quota_must_cover_booth_price_quotas
    return if quota.nil?

    allocated_quota = exhibitor_booth_prices.where.not(quota: nil).sum(:quota)
    return if allocated_quota <= quota

    errors.add(:quota, 'must be greater than or equal to total booth price quotas')
  end
end
