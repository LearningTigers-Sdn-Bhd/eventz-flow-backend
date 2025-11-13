class ExhibitorOwner < ApplicationRecord
  # --- Associations ---
  has_many :exhibitors, class_name: 'Exhibitor', foreign_key: 'exhibitor_owner_id', dependent: :restrict_with_error

  # --- Validations ---
  validates :name, presence: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
