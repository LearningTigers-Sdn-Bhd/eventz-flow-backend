class EventSponsorshipAttachment < ApplicationRecord
  # --- Associations ---
  belongs_to :event_sponsorship
  belongs_to :event_sponsorship_payment, optional: true
  belongs_to :uploaded_by, class_name: 'User'

  # --- Enums ---
  enum :media_type, { image: 0, pdf: 1, other: 2 }
  enum :attachment_type, { other_doc: 0, contract: 1, receipt: 2, logo_pack: 3 }

  # --- Soft Delete ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end
end
