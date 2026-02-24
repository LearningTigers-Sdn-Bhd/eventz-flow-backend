class TicketTypePriceTier < ApplicationRecord
  belongs_to :ticket_type

  validates :label, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :no_overlapping_tiers

  scope :active, -> { where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current) }
  scope :ordered, -> { order(:starts_at) }
  scope :upcoming, -> { where("starts_at > ?", Time.current).order(:starts_at) }

  def active?
    Time.current.between?(starts_at, ends_at)
  end

  private

  def ends_at_after_starts_at
    return unless starts_at && ends_at
    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end

  def no_overlapping_tiers
    return unless ticket_type && starts_at && ends_at

    overlapping = ticket_type.ticket_type_price_tiers
      .where.not(id: id)
      .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)

    if overlapping.exists?
      errors.add(:base, "Date range overlaps with '#{overlapping.first.label}'")
    end
  end
end
