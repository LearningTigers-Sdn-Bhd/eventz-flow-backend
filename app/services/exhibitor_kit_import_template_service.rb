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

  # Sourced from the event's configured exhibitor_labels_data schema (Event Settings)
  # rather than scanning existing exhibitor_kits — a fresh event with zero exhibitors
  # booked yet still gets its custom columns, instead of only appearing once someone
  # has already registered with that field filled in.
  def custom_field_headers
    (@event.exhibitor_labels_data || {}).values
  end

  def build_exhibitors_sheet(package)
    package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
      sheet.add_row(FIXED_HEADERS + custom_field_headers)
    end
  end

  # Two separate remaining-quota columns because a booth price's own quota being
  # "Unlimited" does not mean it's actually bookable — its zone can still be capped
  # (and vice versa). Showing only one number was what made row 3's "quota
  # exceeded" import error look like a bug: the price-level column said Unlimited
  # while the zone was in fact full.
  def build_reference_sheet(package)
    prices = @event.exhibitor_booth_prices.includes(:exhibitor_zone, :exhibitor_packages).order(:booth_type, :label)
    booth_price_sold = sold_quantity_by_booth_price
    zone_sold = sold_quantity_by_zone

    package.workbook.add_worksheet(name: 'Reference') do |sheet|
      sheet.add_row([
        'Booth Type', 'Zone', 'Price Label', 'Current Price',
        'Remaining Quota (This Price)', 'Remaining Quota (Zone)', 'Package Name'
      ])

      prices.each do |price|
        price_remaining = remaining_quota(price.quota, booth_price_sold[price.id])
        zone_remaining = price.exhibitor_zone ? remaining_quota(price.exhibitor_zone.quota, zone_sold[price.exhibitor_zone_id]) : 'N/A'

        if price.exhibitor_packages.any?
          price.exhibitor_packages.each do |pkg|
            sheet.add_row([price.booth_type, price.zone, price.label, price.current_price, price_remaining, zone_remaining, pkg.name])
          end
        else
          sheet.add_row([price.booth_type, price.zone, price.label, price.current_price, price_remaining, zone_remaining, nil])
        end
      end
    end
  end

  def remaining_quota(quota, sold)
    return 'Unlimited' if quota.nil?

    [quota - sold.to_i, 0].max
  end

  def sold_quantity_by_booth_price
    ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .group(:exhibitor_booth_price_id)
      .sum(:booth_quantity)
  end

  def sold_quantity_by_zone
    ExhibitorKit.joins(:event_vendor, :exhibitor_booth_price)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .group('exhibitor_booth_prices.exhibitor_zone_id')
      .sum(:booth_quantity)
  end
end
