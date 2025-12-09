class ExhibitorKitPayment < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :payee, class_name: "User"

  has_many :exhibitor_kit_items
  has_many :exhibitor_kit_printings

  enum :status, { pending: 0, submitted: 1, verified: 2, rejected: 3 }
  enum :payment_source, { manual_bank_in: "manual_bank_in", payment_gateway: "payment_gateway" }

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_source, presence: true, if: :submitted?
  validates :payment_proof_url, presence: true, if: :submitted?
  validates :external_ref, presence: true, if: :payment_gateway?
end
