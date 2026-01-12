class EventSponsorshipTier < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :event
  has_many :event_sponsorships, dependent: :nullify

  # --- Validations ---
  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  
  # --- Enums ---
  enum :sponsorship_type_default, { monetary: 0, in_kind: 1, mixed: 2 }, prefix: :type

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
