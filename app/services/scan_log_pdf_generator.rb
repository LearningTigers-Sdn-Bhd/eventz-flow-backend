require 'prawn'
require 'prawn/table'

Prawn::Fonts::AFM.hide_m17n_warning = true

# Renders an event's scan logs as a PDF table (one row per scan). Accepts the
# already-filtered, ordered relation from the controller so the export mirrors
# whatever the user sees on screen.
class ScanLogPdfGenerator
  def initialize(event, logs)
    @event = event
    @logs = logs.to_a
  end

  def generate
    pdf = Prawn::Document.new(page_size: 'A4', page_layout: :landscape, margin: [40, 40, 40, 40])

    pdf.font_families.update('Helvetica' => {
      normal: 'Helvetica',
      bold: 'Helvetica-Bold',
      italic: 'Helvetica-Oblique'
    })
    pdf.font 'Helvetica'

    build_header(pdf)
    build_table(pdf)

    pdf.number_pages 'Page <page> of <total>', at: [pdf.bounds.right - 100, -10], size: 8
    pdf.render
  end

  private

  def build_header(pdf)
    pdf.text @event.title, size: 18, style: :bold
    pdf.move_down 2
    pdf.text "Scan Log Report  •  Generated #{Time.current.strftime('%d %b %Y, %I:%M %p')}",
             size: 9, color: '6B7280', style: :italic
    pdf.move_down 4
    pdf.text "Total scans: #{@logs.size}", size: 10, color: '111827'
    pdf.move_down 12
  end

  def build_table(pdf)
    headers = ScanLogReportRows::HEADERS
    rows = ScanLogReportRows.for(@logs).map do |row|
      row.map { |value| format_value(value) }
    end

    table_data = [headers] + rows

    pdf.table(table_data, header: true, width: pdf.bounds.width,
              cell_style: { size: 8, border_color: 'D1D5DB', padding: [5, 6, 5, 6] }) do |t|
      t.row(0).background_color = '2766EC'
      t.row(0).text_color = 'FFFFFF'
      t.row(0).font_style = :bold
      t.row(0).size = 8
      # Alternating row shading for readability.
      (1..rows.size).each do |i|
        t.row(i).background_color = i.odd? ? 'FFFFFF' : 'F3F4F6'
      end
      # Name/Email/Location/Scanned By wider; Type/Source narrower; Scanned At fixed.
      t.column(0).width = pdf.bounds.width * 0.16
      t.column(1).width = pdf.bounds.width * 0.18
      t.column(2).width = pdf.bounds.width * 0.09
      t.column(3).width = pdf.bounds.width * 0.06
      t.column(4).width = pdf.bounds.width * 0.11
      t.column(5).width = pdf.bounds.width * 0.13
      t.column(6).width = pdf.bounds.width * 0.13
      t.column(7).width = pdf.bounds.width * 0.14
    end
  end

  def format_value(value)
    return '—' if value.nil? || value.to_s.empty?
    return value.strftime('%Y-%m-%d %H:%M') if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    value.to_s
  end
end
