class ExhibitorTeamMemberPayment < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :payee, class_name: "User", optional: true

  has_one_attached :payment_proof, dependent: :purge_later

  enum :status, { pending: 0, submitted: 1, verified: 2, rejected: 3 }
  enum :payment_source, { manual_bank_in: "manual_bank_in", payment_gateway: "payment_gateway" }

  validates :extra_member_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :fee_per_member, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_source, presence: true, if: :submitted?
  validate :acceptable_payment_proof
  validates :payment_proof, presence: true, if: :submitted?
  validates :external_ref, presence: true, if: :payment_gateway?

  delegate :event, to: :exhibitor_kit

  private

  def acceptable_payment_proof
    return unless payment_proof.attached?

    unless payment_proof.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp application/pdf])
      errors.add(:payment_proof, 'must be a JPEG, PNG, GIF, WebP, or PDF')
    end

    if payment_proof.blob.byte_size > 5.megabytes
      errors.add(:payment_proof, 'is too large (max 5MB)')
    end
  end
end
