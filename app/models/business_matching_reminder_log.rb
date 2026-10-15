class BusinessMatchingReminderLog < ApplicationRecord
  belongs_to :business_matching_booking

  validates :reminder_type, presence: true
  validates :business_matching_booking_id, uniqueness: { scope: :reminder_type }
end
