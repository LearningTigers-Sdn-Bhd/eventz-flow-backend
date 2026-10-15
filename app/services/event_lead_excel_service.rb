require 'caxlsx'

# Exports an exhibitor's captured leads for one event as a styled single-sheet
# Excel workbook. Mirrors the visual conventions of ExhibitorKitExcelService
# (brand header, zebra rows, borders) so exports look consistent across the app.
class EventLeadExcelService
  BRAND_NAVY = 'FF1F2A44'
  BRAND_BLUE = 'FF2766EC'
  LIGHT_GRAY = 'FFF3F4F6'
  BORDER_GRAY = 'FFD1D5DB'
  TEXT_DARK = 'FF111827'
  TEXT_MUTED = 'FF6B7280'
  WHITE = 'FFFFFFFF'

  HEADERS = ['Name', 'Email', 'Phone', 'Notes', 'Scanned By', 'Captured At'].freeze

  # leads: already policy-scoped EventLead relation/array (caller owns authorization)
  def self.export(event, leads)
    new(event, leads).export
  end

  def initialize(event, leads)
    @event = event
    @leads = leads.to_a
  end

  def export
    package = Axlsx::Package.new(author: 'EventzFlow')
    define_styles(package)
    build_leads_sheet(package)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    slug = @event.title.parameterize.presence || @event.id.to_s
    file_path = exports_dir.join("#{slug}-leads-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    export_log = ExportLog.create!(event_id: @event.id, type: 'event-lead-list', sheet_path: file_path.to_s)

    { file_path: file_path.to_s, export_log: export_log }
  end

  private

  def define_styles(package)
    s = package.workbook.styles
    @styles = {
      title: s.add_style(sz: 16, b: true, fg_color: WHITE, bg_color: BRAND_NAVY,
                          alignment: { vertical: :center, horizontal: :left, indent: 1 }),
      subtitle: s.add_style(sz: 10, i: true, fg_color: TEXT_MUTED),
      table_header: s.add_style(sz: 10, b: true, fg_color: WHITE, bg_color: BRAND_BLUE,
                                 alignment: { vertical: :center, horizontal: :center, wrap_text: true },
                                 border: cell_border),
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

  def build_leads_sheet(package)
    package.workbook.add_worksheet(name: 'Leads') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.column_widths 24, 28, 16, 40, 20, 20
      sheet.merge_cells('A1:F1')
      sheet.add_row [@event.title], style: @styles[:title], height: 28
      sheet.add_row ["Leads Report  •  #{@leads.size} captured  •  Generated #{Time.current.strftime('%d %b %Y, %I:%M %p')}"],
                    style: @styles[:subtitle]
      sheet.add_row []

      sheet.add_row HEADERS, style: Array.new(HEADERS.size, @styles[:table_header]), height: 18
      header_row_number = sheet.rows.size

      @leads.each_with_index do |lead, index|
        text_style = index.even? ? @styles[:text] : @styles[:text_alt]
        date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]
        info = leadable_info(lead)
        sheet.add_row(
          [info[:name], info[:email], info[:phone], lead.notes, lead.scanned_by&.full_name, lead.created_at],
          style: [text_style, text_style, text_style, text_style, text_style, date_style]
        )
      end

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A#{header_row_number + 1}"
        pane.state = :frozen
        pane.y_split = header_row_number
        pane.active_pane = :bottom_left
      end

      sheet.auto_filter = "A#{header_row_number}:F#{header_row_number}"
    end
  end

  def leadable_info(lead)
    case lead.leadable_type
    when 'Visitor'
      v = lead.leadable
      { name: v&.full_name, email: v&.email, phone: v&.phone }
    when 'Ticket'
      t = lead.leadable
      { name: t&.attendee_name, email: t&.attendee_email, phone: t&.attendee_phone }
    else
      { name: nil, email: nil, phone: nil }
    end
  end
end
