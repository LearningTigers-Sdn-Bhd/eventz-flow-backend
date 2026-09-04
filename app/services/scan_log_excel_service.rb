require 'caxlsx'

# Exports an event's scan logs as an Excel workbook:
#   1. Summary - headline counts (total scans, by type, by source)
#   2. Scan Logs - one row per scan with attendee/location/scanner details
# Accepts the already-filtered, ordered relation from the controller so the export
# mirrors whatever the user sees on screen.
class ScanLogExcelService
  BRAND_NAVY = 'FF1F2A44'
  BRAND_BLUE = 'FF2766EC'
  LIGHT_GRAY = 'FFF3F4F6'
  BORDER_GRAY = 'FFD1D5DB'
  TEXT_DARK = 'FF111827'
  TEXT_MUTED = 'FF6B7280'
  WHITE = 'FFFFFFFF'

  def self.export(event, logs)
    new(event, logs).export
  end

  def initialize(event, logs)
    @event = event
    @logs = logs.to_a
  end

  def export
    package = Axlsx::Package.new(author: 'EventzFlow')
    define_styles(package)

    build_summary_sheet(package)
    build_logs_sheet(package)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("scan-logs-#{@event.id}-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    export_log = ExportLog.create!(event_id: @event.id, type: 'scan-log-list', sheet_path: file_path.to_s)

    { file_path: file_path.to_s, export_log: export_log }
  end

  private

  def define_styles(package)
    s = package.workbook.styles
    @styles = {
      title: s.add_style(sz: 16, b: true, fg_color: WHITE, bg_color: BRAND_NAVY,
                          alignment: { vertical: :center, horizontal: :left, indent: 1 }),
      subtitle: s.add_style(sz: 10, i: true, fg_color: TEXT_MUTED),
      section_header: s.add_style(sz: 12, b: true, fg_color: BRAND_NAVY,
                                   border: { style: :medium, color: BRAND_NAVY, edges: [:bottom] }),
      stat_label: s.add_style(sz: 9, fg_color: TEXT_MUTED, b: true,
                               bg_color: LIGHT_GRAY, border: cell_border),
      stat_value: s.add_style(sz: 13, b: true, fg_color: TEXT_DARK, border: cell_border),
      table_header: s.add_style(sz: 10, b: true, fg_color: WHITE, bg_color: BRAND_BLUE,
                                 alignment: { vertical: :center, horizontal: :center, wrap_text: true },
                                 border: cell_border),
      cell: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border),
      cell_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border),
      text: s.add_style(sz: 10, fg_color: TEXT_DARK, border: cell_border, format_code: '@'),
      text_alt: s.add_style(sz: 10, fg_color: TEXT_DARK, bg_color: LIGHT_GRAY, border: cell_border,
                             format_code: '@'),
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
      sheet.column_widths 28, 22, 22, 22, 22, 22
      sheet.merge_cells('A1:F1')
      sheet.add_row [@event.title], style: @styles[:title], height: 28
      sheet.add_row ["Scan Log Report  •  Generated #{Time.current.strftime('%d %b %Y, %I:%M %p')}"],
                    style: @styles[:subtitle]
      sheet.add_row []

      sheet.add_row ['Overview'], style: @styles[:section_header]
      merge_row_across(sheet, 6)

      ticket_count = @logs.count { |l| l.scannable_type == 'Ticket' }
      visitor_count = @logs.count { |l| l.scannable_type == 'Visitor' }
      staff_count = @logs.count { |l| l.source == 'staff_scan' }
      self_count = @logs.count { |l| l.source == 'self_check_in' }
      kiosk_count = @logs.count { |l| l.source == 'kiosk' }

      sheet.add_row ['Total Scans', 'Tickets', 'Visitors', 'Staff scan', 'Self check-in', 'Public Check-in Page'],
                    style: Array.new(6, @styles[:stat_label])
      sheet.add_row [@logs.size, ticket_count, visitor_count, staff_count, self_count, kiosk_count],
                    style: Array.new(6, @styles[:stat_value]), height: 20

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end

  # Merges the last-added row's cells across `column_count` columns (e.g. for section banners).
  def merge_row_across(sheet, column_count)
    row = sheet.rows.last
    sheet.merge_cells(row.cells[0..(column_count - 1)])
  end

  # --- Sheet 2: Scan Logs ---

  def build_logs_sheet(package)
    headers = ScanLogReportRows::HEADERS
    # Name, Email, Phone, Type, Source, Location, Scanned By, Scanned At
    column_widths = [26, 30, 18, 10, 20, 22, 22, 20]

    package.workbook.add_worksheet(name: 'Scan Logs') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      sheet.column_widths(*column_widths)

      rows = ScanLogReportRows.for(@logs)
      rows.each_with_index do |row, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        text_style = index.even? ? @styles[:text] : @styles[:text_alt]
        date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]

        sheet.add_row(
          row,
          style: [style, style, text_style, style, style, style, style, date_style]
        )
      end

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A2'
        pane.state = :frozen
        pane.y_split = 1
      end

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end
end
