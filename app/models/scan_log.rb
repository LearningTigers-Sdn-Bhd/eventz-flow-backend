class ScanLog < ApplicationRecord
  belongs_to :event
  belongs_to :scannable, polymorphic: true
  belongs_to :event_location, optional: true
  belongs_to :scanned_by, class_name: 'User', optional: true

  enum :source, { staff_scan: 0, self_check_in: 1, kiosk: 2, reprint: 3 }

  validates :scanned_at, presence: true

  scope :for_scannable, lambda { |record|
    where(scannable_type: record.class.name, scannable_id: record.id)
  }
  scope :on_date, ->(date) { where(scanned_at: date.all_day) }
end
