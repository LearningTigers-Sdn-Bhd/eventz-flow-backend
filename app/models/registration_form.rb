class RegistrationForm < ApplicationRecord
  belongs_to :event
  has_many :registration_form_ticket_types, dependent: :destroy
  has_many :ticket_types, through: :registration_form_ticket_types

  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :event_id }
end
