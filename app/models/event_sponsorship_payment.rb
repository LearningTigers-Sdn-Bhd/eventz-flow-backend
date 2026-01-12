class EventSponsorshipPayment < ApplicationRecord
  # --- Associations ---
  belongs_to :event_sponsorship
  has_many :event_sponsorship_attachments, dependent: :nullify

  # --- Validations ---
  validates :amount, numericality: { greater_than: 0 }
  validates :received_at, presence: true

  # --- Enums ---
  enum :method, { bank_transfer: 0, cash: 1, card: 2, cheque: 3, other: 4 }

  # --- Callbacks ---
  after_commit :update_sponsorship_totals

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

  private

  def update_sponsorship_totals
    event_sponsorship.update_payment_totals!
  end
end
