class RegistrationForm < ApplicationRecord
  belongs_to :event
  has_many :registration_form_ticket_types, dependent: :destroy
  has_many :ticket_types, through: :registration_form_ticket_types
  has_many :pass_bundles, dependent: :restrict_with_error
  has_one :registration_form_rsvp_setting, dependent: :destroy

  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :event_id }
  validate :custom_labels_data_must_be_array

  private

  def custom_labels_data_must_be_array
    return if custom_labels_data.is_a?(Array)

    errors.add(:custom_labels_data, 'must be an array')
  end
end
