class EventPrintingServicePriceTier < ApplicationRecord
  belongs_to :event_printing_service

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validates :label, presence: true
end
