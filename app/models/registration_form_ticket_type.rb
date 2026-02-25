class RegistrationFormTicketType < ApplicationRecord
  belongs_to :registration_form
  belongs_to :ticket_type

  enum :registration_mode, { single: 0, group: 1 }, prefix: true

  validates :min_attendees, numericality: { greater_than_or_equal_to: 1 }
  validate :custom_labels_data_must_be_array
  validate :max_attendees_not_less_than_min

  private

  def max_attendees_not_less_than_min
    return if max_attendees.blank?
    return if max_attendees >= min_attendees

    errors.add(:max_attendees, 'must be greater than or equal to min_attendees')
  end

  def custom_labels_data_must_be_array
    return if custom_labels_data.is_a?(Array)

    errors.add(:custom_labels_data, 'must be an array')
  end
end
