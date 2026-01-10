class VisitorVendorStamp < ApplicationRecord
  include TimeSeriesAnalytics

  # --- Associations ---
  belongs_to :visitor
  belongs_to :event_vendor

  # --- Validations ---
  validates :visitor_id, presence: true
  validates :event_vendor_id, presence: true
  validates :visitor_id, uniqueness: { scope: :event_vendor_id, message: 'has already been stamped by this vendor' }
end
