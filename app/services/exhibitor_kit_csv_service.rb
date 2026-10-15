require 'csv'

# Plain CSV export of an event's exhibitor kit registrations - same columns as the
# "Registered Exhibitor" sheet in ExhibitorKitExcelService (see ExhibitorKitReportRows).
class ExhibitorKitCsvService
  def self.export(event_id)
    new(event_id).export
  end

  def initialize(event_id)
    @event = Event.find(event_id)
    @kits = ExhibitorKit
      .joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .includes(:event_vendor, :exhibitor_booth_price, :exhibitor_package, :exhibitor_registration_payment)
      .order(:created_at)
      .to_a
  end

  def export
    CSV.generate do |csv|
      csv << ExhibitorKitReportRows::HEADERS
      ExhibitorKitReportRows.for(@kits).each do |row|
        csv << row.map { |value| value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.strftime('%Y-%m-%d %H:%M:%S') : value }
      end
    end
  end
end
