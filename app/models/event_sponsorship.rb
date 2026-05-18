class EventSponsorship < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :event
  belongs_to :sponsor
  belongs_to :event_sponsorship_tier, optional: true
  belongs_to :internal_owner_user, class_name: 'User', optional: true

  has_many :event_sponsorship_payments, dependent: :destroy
  has_many :event_sponsorship_attachments, dependent: :destroy
  has_many :event_sponsorship_items, dependent: :destroy

  # --- Validations ---
  validates :title, presence: true
  validates :total_sponsor_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # --- Enums ---
  enum :sponsorship_type, { monetary: 0, in_kind: 1, mixed: 2 }
  enum :status, { pending: 0, partially_received: 1, received: 2, cancelled: 3 }

  # --- Callbacks ---
  before_save :snapshot_tier_name, if: :event_sponsorship_tier_id_changed?
  before_create :snapshot_contact_info

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

  # --- Logic ---
  def update_payment_totals!
    total_payments = event_sponsorship_payments.sum(:amount)
    total_inkind = event_sponsorship_items.where(received: true).sum(:total_value)
    
    total_received = total_payments + total_inkind
    last_payment = event_sponsorship_payments.maximum(:received_at)

    new_status = if cancelled_at.present?
                   :cancelled
                 elsif total_received >= (total_sponsor_amount || 0) && (total_sponsor_amount || 0) > 0
                   :received
                 elsif total_received > 0
                   :partially_received
                 else
                   :pending
                 end

    update(
      received_total: total_received,
      last_received_at: last_payment,
      status: new_status
    )
  end

  private

  def snapshot_tier_name
    self.tier_name_snapshot = event_sponsorship_tier&.name
  end

  def snapshot_contact_info
    return if contact_name.present? # Don't overwrite if manually set

    self.contact_name = sponsor.default_contact_name
    self.contact_email = sponsor.default_email
    self.contact_whatsapp = sponsor.default_whatsapp
    self.contact_position = sponsor.default_contact_position
  end
end
