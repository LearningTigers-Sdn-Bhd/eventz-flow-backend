class ExhibitorKitItem < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :rentable_item
  belongs_to :exhibitor_kit_payment, optional: true

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :agreed_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
