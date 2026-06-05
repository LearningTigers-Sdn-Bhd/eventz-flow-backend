# frozen_string_literal: true

class ExhibitorTeamMemberPayment < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :payee, class_name: 'User', optional: true

  has_one_attached :payment_proof, dependent: :purge_later

  enum :status, { pending: 0, submitted: 1, verified: 2, rejected: 3 }

  after_commit :confirm_excess_member_tickets, if: :just_verified?
  enum :payment_source, { manual_bank_in: 'manual_bank_in', payment_gateway: 'payment_gateway' }

  validates :extra_member_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :fee_per_member, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_source, presence: true, if: :submitted?
  validate :acceptable_payment_proof
  validates :payment_proof, presence: true, if: :submitted?
  validates :gateway, presence: true, if: :payment_gateway?
  validates :gateway_payment_id, presence: true, if: -> { payment_gateway? && verified? }

  delegate :event, to: :exhibitor_kit

  private

  def just_verified?
    saved_change_to_status? && verified?
  end

  def confirm_excess_member_tickets
    ExhibitorTeamMemberPaymentVerificationService.new(self).call
  end

  def acceptable_payment_proof
    return unless payment_proof.attached?

    unless payment_proof.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp application/pdf])
      errors.add(:payment_proof, 'must be a JPEG, PNG, GIF, WebP, or PDF')
    end

    return unless payment_proof.blob.byte_size > 5.megabytes

    errors.add(:payment_proof, 'is too large (max 5MB)')
  end
end
