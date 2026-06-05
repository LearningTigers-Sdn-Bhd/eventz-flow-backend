class ExhibitorBoothPrice < ApplicationRecord
  belongs_to :event
  belongs_to :exhibitor_zone, optional: true
  has_many :exhibitor_kits, dependent: :nullify
  has_many :exhibitor_booth_price_tiers, dependent: :destroy

  delegate :zone, to: :exhibitor_zone, allow_nil: true

  validates :booth_type, presence: true
  validates :label, presence: true, uniqueness: { scope: %i[event_id booth_type exhibitor_zone_id] }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :zone_quota_must_belong_to_event
  validate :quota_must_not_exceed_zone_quota

  def current_price_tier(reference_time = Time.current)
    exhibitor_booth_price_tiers.ordered.find { |tier| tier.active?(reference_time) }
  end

  def current_price(reference_time = Time.current)
    current_price_tier(reference_time)&.price || price
  end

  private

  def zone_quota_must_belong_to_event
    return if exhibitor_zone.blank?
    return if exhibitor_zone.event_id == event_id

    errors.add(:exhibitor_zone_id, 'must belong to the same event')
  end

  def quota_must_not_exceed_zone_quota
    return if exhibitor_zone.blank? || quota.nil?
    return if exhibitor_zone.quota.nil?

    allocated_quota = exhibitor_zone
                      .exhibitor_booth_prices
                      .where.not(id: id)
                      .where.not(quota: nil)
                      .sum(:quota)

    return if allocated_quota + quota <= exhibitor_zone.quota

    errors.add(:quota, 'total booth price quotas cannot exceed zone quota')
  end
end
