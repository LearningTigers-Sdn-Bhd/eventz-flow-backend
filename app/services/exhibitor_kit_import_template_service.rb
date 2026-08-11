require 'caxlsx'

# Generates the .xlsx template organizers fill in and re-upload via
# ExhibitorKitImportService. Two sheets:
#   1. Exhibitors - the rows to fill in
#   2. Reference  - read-only current booth price / zone / package combos
class ExhibitorKitImportTemplateService
  FIXED_HEADERS = [
    'Vendor Email', 'Vendor Name', 'Vendor Phone',
    'Company Name', 'Company Address',
    'PIC Name', 'PIC Contact', 'PIC Email',
    'Booth Type', 'Zone', 'Price Label', 'Package Name',
    'Booth Quantity', 'Amount Paid', 'Payment Status'
  ].freeze

  def self.export(event_id)
    new(event_id).export
  end

  def initialize(event_id)
    @event = Event.find(event_id)
  end

  def export
    package = Axlsx::Package.new(author: 'EventzFlow')
    build_exhibitors_sheet(package)
    build_reference_sheet(package)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("exhibitor-import-template-#{@event.id}-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    { file_path: file_path.to_s }
  end

  private

  def custom_field_headers
    keys = ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .pluck(:custom_fields_data)
      .flat_map(&:keys)
      .uniq
      .reject { |key| ExhibitorKit::SYSTEM_CUSTOM_FIELD_KEYS.include?(key) }
      .sort

    keys.map { |key| "Custom: #{key.to_s.tr('_', ' ').split.map(&:capitalize).join(' ')}" }
  end

  def build_exhibitors_sheet(package)
    package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
      sheet.add_row(FIXED_HEADERS + custom_field_headers)
    end
  end

  def build_reference_sheet(package)
    prices = @event.exhibitor_booth_prices.includes(:exhibitor_zone, :exhibitor_packages).order(:booth_type, :label)

    package.workbook.add_worksheet(name: 'Reference') do |sheet|
      sheet.add_row(['Booth Type', 'Zone', 'Price Label', 'Current Price', 'Remaining Quota', 'Package Name'])

      prices.each do |price|
        remaining = price.quota.nil? ? 'Unlimited' : price.quota
        if price.exhibitor_packages.any?
          price.exhibitor_packages.each do |pkg|
            sheet.add_row([price.booth_type, price.zone, price.label, price.current_price, remaining, pkg.name])
          end
        else
          sheet.add_row([price.booth_type, price.zone, price.label, price.current_price, remaining, nil])
        end
      end
    end
  end
end
