class ExhibitorRegistrationPayment < ApplicationRecord
  belongs_to :exhibitor_kit
  has_one_attached :payment_proof, dependent: :purge_later

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[pending submitted rejected paid failed refunded] }
  validates :currency, presence: true
  validates :gateway_order_id, uniqueness: true, allow_nil: true
  validates :gateway_payment_id, uniqueness: true, allow_nil: true

  scope :pending, -> { where(status: "pending") }
  scope :submitted, -> { where(status: "submitted") }
  scope :rejected, -> { where(status: "rejected") }
  scope :paid, -> { where(status: "paid") }
  scope :failed, -> { where(status: "failed") }

  def mark_as_paid!(payment_method: nil, gateway_response: nil)
    transaction do
      update!(status: "paid", paid_at: Time.current, payment_method: payment_method,
        gateway_response: gateway_response)
      exhibitor_kit.update!(payment_status: :paid, booking_status: :paid, reservation_expires_at: nil)
    end
  end

  def mark_as_failed!(gateway_response: nil)
    update!(
      status: "failed",
      gateway_response: gateway_response,
    )

    exhibitor_kit.update!(payment_status: :unpaid)
  end
end
