class ExhibitionContractorProfile < ApplicationRecord
  # --- Associations ---
  belongs_to :user
  has_many :event_exhibition_contractors, dependent: :destroy, inverse_of: :exhibition_contractor_profile
  has_many :events, through: :event_exhibition_contractors

  # --- Attachments ---
  has_one_attached :guidelines_pdf, dependent: :purge_later

  # --- Validations ---
  validates :user_id, uniqueness: { message: 'already has a profile' }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # --- Callbacks ---
  validate :user_must_have_exhibition_contractor_role
  validate :validate_guidelines_pdf

  private

  def user_must_have_exhibition_contractor_role
    if user.present? && !user.exhibition_contractor?
      errors.add(:user, 'must have exhibition_contractor role')
    end
  end

  def validate_guidelines_pdf
    return unless guidelines_pdf.attached?

    unless guidelines_pdf.content_type == 'application/pdf'
      errors.add(:guidelines_pdf, 'must be a PDF file')
    end

    if guidelines_pdf.blob.byte_size > 10.megabytes
      errors.add(:guidelines_pdf, 'must be less than 10MB')
    end
  end
end
