class ExhibitorBoothPrice < ApplicationRecord
  belongs_to :event
  belongs_to :exhibitor_zone, optional: true
  has_many :exhibitor_kits, dependent: :nullify

  delegate :zone, to: :exhibitor_zone, allow_nil: true

  validates :booth_type, presence: true
  validates :label, presence: true, uniqueness: { scope: %i[event_id booth_type exhibitor_zone_id] }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :zone_quota_must_belong_to_event

  private

  def zone_quota_must_belong_to_event
    return if exhibitor_zone.blank?
    return if exhibitor_zone.event_id == event_id

    errors.add(:exhibitor_zone_id, 'must belong to the same event')
  end
end
