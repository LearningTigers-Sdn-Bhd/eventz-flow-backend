# Singleton holding Email Log retention. Rows that prove a delivery problem
# (bounced / complained / suppressed) are kept longer than routine ones.
class EmailLogSetting < ApplicationRecord
  MIN_DAYS = 30 # the retry window and dedupe guard need recent rows
  MAX_DAYS = 3650
  PROTECTED_STATUSES = %w[bounced complained suppressed].freeze

  validates :retention_days, :protected_retention_days,
            numericality: { only_integer: true, greater_than_or_equal_to: MIN_DAYS, less_than_or_equal_to: MAX_DAYS }
  validate :protected_not_shorter_than_routine

  def self.current
    first || create!
  end

  # Rows past their retention window, as one relation (used by the purge job
  # and by the "rows to purge" preview in the UI).
  def purgeable
    routine = EmailDelivery.where.not(status: PROTECTED_STATUSES).where(created_at: ...retention_days.days.ago)
    kept_longer = EmailDelivery.where(status: PROTECTED_STATUSES).where(created_at: ...protected_retention_days.days.ago)
    routine.or(kept_longer)
  end

  private

  def protected_not_shorter_than_routine
    return if retention_days.blank? || protected_retention_days.blank?
    return if protected_retention_days >= retention_days

    errors.add(:protected_retention_days, 'must be at least as long as the normal retention')
  end
end
