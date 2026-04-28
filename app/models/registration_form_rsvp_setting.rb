class RegistrationFormRsvpSetting < ApplicationRecord
  belongs_to :registration_form

  validates :review_sla_hours, numericality: { greater_than: 0 }
  validates :rsvp_expires_in_hours, numericality: { greater_than: 0 }, allow_nil: true
end
