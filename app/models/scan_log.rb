class ScanLog < ApplicationRecord
  include TimeSeriesAnalytics

  belongs_to :event
  belongs_to :scannable, polymorphic: true
  belongs_to :event_location, optional: true
  belongs_to :scanned_by, class_name: 'User', optional: true

  # `rfid_desk` is appended so the stored integers for every existing source
  # keep their meaning. `operation_id` is the RfiDex operation that produced
  # the row (nullable: staff/kiosk scans have none) and is how a webhook can
  # still name the app that checked a guest in, after the commit.
  enum :source, { staff_scan: 0, self_check_in: 1, kiosk: 2, reprint: 3, rfid_desk: 4 }

  validates :scanned_at, presence: true

  scope :for_scannable, lambda { |record|
    where(scannable_type: record.class.name, scannable_id: record.id)
  }
  scope :on_date, ->(date) { where(scanned_at: date.all_day) }
end
