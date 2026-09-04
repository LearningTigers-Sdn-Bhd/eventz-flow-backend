require 'csv'

# Plain CSV export of an event's scan logs - same columns as the Excel and PDF
# reports (see ScanLogReportRows). Accepts the already-filtered, ordered relation
# from the controller so the export mirrors whatever the user sees on screen.
class ScanLogCsvService
  def self.export(logs)
    new(logs).export
  end

  def initialize(logs)
    @logs = logs.to_a
  end

  def export
    CSV.generate do |csv|
      csv << ScanLogReportRows::HEADERS
      ScanLogReportRows.for(@logs).each do |row|
        csv << row.map { |value| format_value(value) }
      end
    end
  end

  private

  def format_value(value)
    return '' if value.nil?
    return value.strftime('%Y-%m-%d %H:%M:%S') if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    value
  end
end
