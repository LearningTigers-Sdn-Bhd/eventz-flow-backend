class ExhibitionContractorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :user
  has_many :event_exhibition_contractors, dependent: :destroy

  # --- Validations ---
  validates :user_id, uniqueness: { message: 'already has a profile' }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # --- Callbacks ---
  validate :user_must_have_exhibition_contractor_role

  private

  def user_must_have_exhibition_contractor_role
    if user.present? && !user.exhibition_contractor?
      errors.add(:user, 'must have exhibition_contractor role')
    end
  end
end
