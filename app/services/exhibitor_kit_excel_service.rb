require 'caxlsx'

# Exports an event's exhibitor kit registrations as a multi-sheet Excel workbook:
#   1. Summary            - headline stats + booth pricing breakdown (mirrors the analytics dashboard)
#   2. Registered Exhibitor - one row per exhibitor kit with company/PIC/booking/payment details
#   3. Exhibitor Crew      - one row per crew member (team member) attached to a kit
class ExhibitorKitExcelService
  BRAND_NAVY = 'FF1F2A44'
  BRAND_BLUE = 'FF2766EC'
  LIGHT_GRAY = 'FFF3F4F6'
  BORDER_GRAY = 'FFD1D5DB'
  TEXT_DARK = 'FF111827'
  TEXT_MUTED = 'FF6B7280'
  WHITE = 'FFFFFFFF'

  def self.export(event_id)
    new(event_id).export
  end

  def initialize(event_id)
    @event = Event.find(event_id)
    @kits = ExhibitorKit
      .joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .includes(:event_vendor, :exhibitor_booth_price, :exhibitor_package,
                :exhibitor_registration_payment, :exhibitor_team_members)
      .order(:created_at)
      .to_a
  end

  def export
    package = Axlsx::Package.new(author: 'EventzFlow')
    define_styles(package)

    build_summary_sheet(package)
    build_kits_sheet(package)
    build_team_members_sheet(package)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("exhibitor-kits-#{@event.id}-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    export_log = ExportLog.create!(event_id: @event.id, type: 'exhibitor-kit-list', sheet_path: file_path.to_s)

    { file_path: file_path.to_s, export_log: export_log }
  end

  private

  def define_styles(package)
    s = package.workbook.styles
    @styles = {
      title: s.add_style(sz: 16, b: true, fg_color: WHITE, bg_color: BRAND_NAVY,
                          alignment: { vertical: :center, horizontal: :left, indent: 1 }),
      subtitle: s.add_style(sz: 10, i: true, fg_color: TEXT_MUTED),
      stat_label: s.add_style(sz: 9, fg_color: TEXT_MUTED, b: true,
                               bg_color: LIGHT_GRAY, border: cell_border),
      stat_value: s.add_style(sz: 13, b: true, fg_color: TEXT_DARK,
                               border: cell_border),
      section_header: s.add_style(sz: 12, b: true, fg_color: BRAND_NAVY,
                                   border: { style: :medium, color: BRAND_NAVY, edges: [:bottom] }),
      table_header: s.add_style(sz: 10, b: true, fg_color: WHITE, bg_color: BRAND_BLUE,
                                 alignment: { vertical: :center, horizontal: :center, wrap_text: true },
                                 border: cell_border),
      cell: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border),
      cell_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border),
      # Forces text format so phone numbers (all-digit ones especially) never get
      # auto-detected as numbers by Excel/Sheets - keeps alignment and leading zeros intact.
      text: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border, format_code: '@'),
      text_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border,
                             format_code: '@'),
      number: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border,
                           alignment: { horizontal: :right }),
      number_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border,
                               alignment: { horizontal: :right }),
      currency: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border, format_code: '\R\M\ #,##0.00',
                             alignment: { horizontal: :right }),
      currency_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border,
                                 format_code: '\R\M\ #,##0.00', alignment: { horizontal: :right }),
      date_cell: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border, format_code: 'yyyy-mm-dd hh:mm'),
      date_cell_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border,
                                  format_code: 'yyyy-mm-dd hh:mm')
    }
  end

  def cell_border
    { style: :thin, color: BORDER_GRAY, edges: %i[top bottom left right] }
  end

  # --- Sheet 1: Summary ---

  def build_summary_sheet(package)
    package.workbook.add_worksheet(name: 'Summary') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.column_widths 24, 18, 18, 18, 18, 18, 18
      sheet.merge_cells('A1:G1')
      sheet.add_row [@event.title], style: @styles[:title], height: 28
      sheet.add_row ["Exhibitor Kit Report  •  Generated #{Time.current.strftime('%d %b %Y, %I:%M %p')}"],
                    style: @styles[:subtitle]
      sheet.add_row []

      sheet.add_row ['Overview'], style: @styles[:section_header]
      merge_row_across(sheet, 7)

      sheet.add_row ['Total Exhibitors', 'Paid', 'Unpaid', 'Collected Revenue', 'Pending Revenue'],
                    style: Array.new(5, @styles[:stat_label])
      sheet.add_row [
        paid_partner_ids.size + unpaid_partner_ids.size,
        paid_partner_ids.size,
        unpaid_partner_ids.size,
        collected_revenue,
        pending_revenue
      ], style: [@styles[:stat_value], @styles[:stat_value], @styles[:stat_value],
                 @styles[:currency], @styles[:currency]], height: 20

      sheet.add_row []
      sheet.add_row ['Booth Pricing Breakdown'], style: @styles[:section_header]
      merge_row_across(sheet, 7)

      headers = ['Pricing', 'Zone', 'Booked', 'Paid', 'Unpaid', 'Collected Revenue', 'Pending Revenue']
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      header_row_number = sheet.rows.size

      breakdown_rows.each_with_index do |row, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        number_style = index.even? ? @styles[:number] : @styles[:number_alt]
        currency_style = index.even? ? @styles[:currency] : @styles[:currency_alt]
        sheet.add_row(
          [row[:label], row[:zone] || 'Unassigned', row[:booked], row[:paid], row[:unpaid],
           row[:collected], row[:pending]],
          style: [style, style, number_style, number_style, number_style,
                  currency_style, currency_style]
        )
      end

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A#{header_row_number + 1}"
        pane.state = :frozen
        pane.y_split = header_row_number
      end

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end

  # Merges the last-added row's cells across `column_count` columns (e.g. for section banners).
  def merge_row_across(sheet, column_count)
    row = sheet.rows.last
    sheet.merge_cells(row.cells[0..(column_count - 1)])
  end

  # --- Sheet 2: Registered Kits ---

  def build_kits_sheet(package)
    headers = ExhibitorKitReportRows::HEADERS
    column_widths = [24, 20, 26, 16, 14, 12, 14, 14, 20, 14, 13, 14, 13, 10, 14, 14, 21]

    package.workbook.add_worksheet(name: 'Registered Exhibitor') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      sheet.column_widths(*column_widths)

      ExhibitorKitReportRows.for(@kits).each_with_index do |row, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        text_style = index.even? ? @styles[:text] : @styles[:text_alt]
        currency_style = index.even? ? @styles[:currency] : @styles[:currency_alt]
        date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]

        sheet.add_row(
          row,
          style: [
            style, style, style, text_style, style, style, text_style, style, style, style,
            currency_style, currency_style, currency_style, style, style, style, date_style
          ]
        )
      end

      sheet.auto_filter = "A1:#{Axlsx.col_ref(headers.size - 1)}#{@kits.size + 1}"
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A2'
        pane.state = :frozen
        pane.y_split = 1
      end

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end

  # --- Sheet 3: Team Members ---

  def build_team_members_sheet(package)
    headers = ['Company Name', 'Booth Number', 'Crew Name', 'Email', 'Phone']
    rows = @kits.flat_map do |kit|
      kit.exhibitor_team_members.map do |member|
        [kit.company_name, kit.booth_number, member.full_name, member.email, member.phone]
      end
    end

    package.workbook.add_worksheet(name: 'Exhibitor Crew') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      sheet.column_widths(24, 16, 22, 26, 16)

      rows.each_with_index do |row, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        text_style = index.even? ? @styles[:text] : @styles[:text_alt]
        sheet.add_row row, style: [style, text_style, style, style, text_style]
      end

      sheet.auto_filter = "A1:#{Axlsx.col_ref(headers.size - 1)}#{rows.size + 1}" if rows.any?
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A2'
        pane.state = :frozen
        pane.y_split = 1
      end

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end

  # --- Shared computation (mirrors EventAnalyticsController) ---

  def paid_partner_ids
    @paid_partner_ids ||= @kits.select(&:settled?).map(&:event_vendor_id).uniq
  end

  def unpaid_partner_ids
    @unpaid_partner_ids ||= @kits.map(&:event_vendor_id).uniq - paid_partner_ids
  end

  def collected_revenue
    collected_revenue_for(@kits)
  end

  def pending_revenue
    @kits.select(&:unpaid?).sum(&:booking_value).round(2).to_f
  end

  def breakdown_rows
    grouped = @kits.group_by do |kit|
      [kit.exhibitor_booth_price_id, kit.exhibitor_package_id,
       kit.exhibitor_booth_price&.label || kit.booth_type]
    end

    booked_rows = grouped.map do |_key, kits|
      first_kit = kits.first
      booth_price = first_kit.exhibitor_booth_price
      paid_kits = kits.select(&:settled?)
      unpaid_kits = kits.select(&:unpaid?)

      {
        label: booth_price&.label || first_kit.booth_type.to_s.humanize,
        zone: booth_price&.zone,
        booked: kits.sum { |k| [k.booth_quantity.to_i, 1].max },
        paid: paid_kits.sum { |k| [k.booth_quantity.to_i, 1].max },
        unpaid: unpaid_kits.sum { |k| [k.booth_quantity.to_i, 1].max },
        collected: collected_revenue_for(kits),
        pending: unpaid_kits.sum(&:booking_value).round(2).to_f
      }
    end

    (booked_rows + unbooked_price_rows).sort_by { |row| [row[:label], row[:zone].to_s] }
  end

  # Booth pricing tiers nobody has booked yet - included so the report shows the full
  # catalog, not just what's sold (matches the on-screen analytics breakdown).
  def unbooked_price_rows
    booked_price_ids = @kits.map(&:exhibitor_booth_price_id).compact.uniq

    @event.exhibitor_booth_prices.includes(:exhibitor_zone)
      .to_a
      .reject { |booth_price| booked_price_ids.include?(booth_price.id) }
      .map do |booth_price|
        { label: booth_price.label, zone: booth_price.zone, booked: 0, paid: 0, unpaid: 0,
          collected: 0.0, pending: 0.0 }
      end
  end

  def collected_revenue_for(kits)
    kits.select(&:paid?).sum do |kit|
      payment = kit.exhibitor_registration_payment
      next payment.amount.to_d if payment&.status == 'paid'
      next kit.amount_paid.to_d if payment.nil?

      0.to_d
    end.round(2).to_f
  end
end
