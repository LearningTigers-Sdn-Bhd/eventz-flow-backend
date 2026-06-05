class ExhibitorBoothPriceTier < ApplicationRecord
  FAR_FUTURE_DATE = Time.zone.local(9999, 12, 31).freeze

  belongs_to :exhibitor_booth_price

  validates :label, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validate :end_date_after_start_date
  validate :no_overlapping_tiers

  scope :ordered, -> { order(:start_date, :id) }

  def active?(reference_time = Time.current)
    start_date <= reference_time && (end_date.nil? || end_date >= reference_time)
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date > start_date

    errors.add(:end_date, 'must be after start_date')
  end

  def no_overlapping_tiers
    return unless exhibitor_booth_price && start_date

    overlapping_tier = exhibitor_booth_price.exhibitor_booth_price_tiers
                                          .where.not(id: id)
                                          .ordered
                                          .detect do |tier|
      overlaps?(tier)
    end

    return unless overlapping_tier

    errors.add(:base, "Date range overlaps with '#{overlapping_tier.label}'")
  end

  def overlaps?(other_tier)
    range_end = end_date || FAR_FUTURE_DATE
    other_range_end = other_tier.end_date || FAR_FUTURE_DATE

    start_date < other_range_end && other_tier.start_date < range_end
  end
end
