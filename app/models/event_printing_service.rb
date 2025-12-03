class EventPrintingService < ApplicationRecord
  belongs_to :event
  belongs_to :printing_service
end
