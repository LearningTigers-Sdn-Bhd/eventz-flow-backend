class TicketPayment < ApplicationRecord
  belongs_to :ticket
  belongs_to :received_by, class_name: 'User', optional: true

  has_one_attached :payment_proof, dependent: :purge_later

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[pending paid failed refunded] }

  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(status: "paid") }
  scope :failed, -> { where(status: "failed") }

  def mark_as_paid!(payment_method: nil, gateway_response: nil)
    update!(
      status: "paid",
      paid_at: Time.current,
      payment_method: payment_method,
      gateway_response: gateway_response
    )
    ticket.update!(payment_status: "paid")
  end

  def mark_as_failed!(gateway_response: nil)
    update!(
      status: "failed",
      gateway_response: gateway_response
    )
    ticket.update!(payment_status: "failed")
  end

  def online_payment?
    gateway.present?
  end

  def cash_payment?
    payment_method == "cash"
  end
end
