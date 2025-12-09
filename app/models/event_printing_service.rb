class EventPrintingService < ApplicationRecord
  belongs_to :event
  belongs_to :printing_service
  has_many :event_printing_service_price_tiers, dependent: :destroy
end
