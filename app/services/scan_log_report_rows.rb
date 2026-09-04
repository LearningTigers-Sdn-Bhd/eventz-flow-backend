# Shared column/row builder for scan log reports (Excel + CSV + PDF) so all export
# formats always show the exact same data - one place to add/rename a column.
class ScanLogReportRows
  HEADERS = [
    'Name', 'Email', 'Phone', 'Type', 'Source', 'Location', 'Scanned By', 'Scanned At'
  ].freeze

  SOURCE_LABELS = {
    'staff_scan' => 'Staff scan',
    'self_check_in' => 'Self check-in',
    'kiosk' => 'Public Check-in Page'
  }.freeze

  def self.for(logs)
    logs.map do |log|
      scannable = log.scannable

      [
        scannable.is_a?(Ticket) ? scannable.attendee_name : scannable&.full_name,
        scannable.is_a?(Ticket) ? scannable.attendee_email : scannable&.email,
        scannable.is_a?(Ticket) ? scannable.attendee_phone : scannable&.phone,
        log.scannable_type,
        SOURCE_LABELS[log.source] || log.source.to_s.titleize,
        log.event_location&.name,
        log.scanned_by&.full_name || SOURCE_LABELS[log.source] || log.source.to_s.titleize,
        log.scanned_at
      ]
    end
  end
end
