class TicketCheckIn < ApplicationRecord
  include TimeSeriesAnalytics

  belongs_to :ticket
  belongs_to :scanned_by, class_name: 'User', optional: true

  validates :check_in_at, presence: true

  # Database handles uniqueness via idx_ticket_check_ins_unique_per_day index
  # Custom validation for better error messages
  validate :unique_per_day, on: :create

  private

  def unique_per_day
    return unless ticket_id.present? && check_in_at.present?

    date = check_in_at.to_date
    range = date.in_time_zone.beginning_of_day..date.in_time_zone.end_of_day
    existing = TicketCheckIn.where(ticket_id: ticket_id)
                            .where(check_in_at: range)
                            .exists?
    errors.add(:ticket, 'already checked in today') if existing
  end
end
