class EventLead < ApplicationRecord
  include TimeSeriesAnalytics

  # --- Associations ---
  belongs_to :leadable, polymorphic: true  # Visitor or Ticket
  belongs_to :event_vendor
  belongs_to :scanned_by, class_name: 'User', optional: true

  # --- Validations ---
  validates :leadable_type, presence: true, inclusion: { in: %w[Visitor Ticket] }
  validates :leadable_id, presence: true
  validates :leadable_id, uniqueness: {
    scope: [:event_vendor_id, :leadable_type],
    message: 'has already been captured as a lead by this vendor'
  }
end
