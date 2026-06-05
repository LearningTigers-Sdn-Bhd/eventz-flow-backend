class EventSponsorshipAttachment < ApplicationRecord
  # --- Associations ---
  belongs_to :event_sponsorship
  belongs_to :event_sponsorship_payment, optional: true
  belongs_to :uploaded_by, class_name: 'User'

  has_one_attached :file

  # --- Enums ---
  enum :media_type, { image: 0, pdf: 1, other: 2 }
  enum :attachment_type, { other_doc: 0, contract: 1, receipt: 2, logo_pack: 3 }

  # --- Validations ---
  validates :file, presence: true
  validates :attachment_type, presence: true

  # --- Callbacks ---
  before_validation :extract_metadata

  # --- Soft Delete ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  # --- Methods ---
  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)
  end

  private

  def extract_metadata
    if file.attached?
      self.file_name = file.filename.to_s if file_name.blank?
      self.mime_type = file.content_type if mime_type.blank?
      self.file_size = file.byte_size if file_size.blank?
      
      if mime_type.present?
        if mime_type.start_with?('image/')
          self.media_type = :image
        elsif mime_type == 'application/pdf'
          self.media_type = :pdf
        else
          self.media_type = :other
        end
      end
    end
  end
end
