class ExhibitionContractorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :user
  has_many :event_exhibition_contractors, dependent: :destroy

  # --- Validations ---
  validates :company_name, presence: true
  validates :contact_person, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true
end
