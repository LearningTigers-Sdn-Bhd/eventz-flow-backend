# frozen_string_literal: true

class BusinessMatchingBooking < ApplicationRecord
  belongs_to :business_matching_session
  belongs_to :host_user, class_name: 'User', optional: true
  belongs_to :requester_participant, class_name: 'BusinessMatchingParticipant', optional: true
  belongs_to :receiver_participant, class_name: 'BusinessMatchingParticipant', optional: true

  validates :name, presence: true
  validates :email, presence: true
  validates :phone, presence: true
  validates :booking_date, presence: true
  validates :booking_time, presence: true
  validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true
  validates :payment_status, presence: true

  # Custom validation to ensure host is not double-booked for active bookings
  validate :host_not_double_booked, if: -> { status != 'Cancelled' && host_user_id.present? }
  validate :receiver_not_double_booked, if: -> { status != 'Cancelled' && receiver_participant_id.present? }

  private

  def host_not_double_booked
    overlapping_bookings = BusinessMatchingBooking
                             .where(host_user_id: host_user_id, booking_date: booking_date, booking_time: booking_time)
                             .where.not(id: id)
                             .where.not(status: 'Cancelled')

    if overlapping_bookings.exists?
      errors.add(:base, "Host is already booked at this date and time")
    end
  end

  def receiver_not_double_booked
    overlapping_bookings = BusinessMatchingBooking
                             .where(receiver_participant_id: receiver_participant_id, booking_date: booking_date, booking_time: booking_time)
                             .where.not(id: id)
                             .where.not(status: 'Cancelled')

    if overlapping_bookings.exists?
      errors.add(:base, "The participant is already booked at this date and time")
    end
  end
end
