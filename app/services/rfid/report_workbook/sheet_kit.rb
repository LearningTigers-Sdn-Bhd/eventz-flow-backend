require 'caxlsx'

module Rfid
  class ReportWorkbook
    # Palette, cell styles and the one table layout every report sheet shares,
    # so a sheet only says what its columns and rows are.
    #
    # A cell is a plain value, or `[value, tone]` to colour it (a status chip).
    # Text is always written as a string cell, so a guest named `=cmd|calc`
    # shows as text and never evaluates as a formula.
    class SheetKit
      NAVY = 'FF1F2A44'.freeze
      BLUE = 'FF2766EC'.freeze
      LIGHT = 'FFF3F4F6'.freeze
      BORDER = 'FFD1D5DB'.freeze
      INK = 'FF111827'.freeze
      MUTED = 'FF6B7280'.freeze
      WHITE = 'FFFFFFFF'.freeze

      # tone => [fill, text]
      TONES = {
        good: %w[FFDCFCE7 FF166534], warn: %w[FFFEF3C7 FF92400E],
        bad: %w[FFFEE2E2 FF991B1B], info: %w[FFDBEAFE FF1E40AF]
      }.freeze

      KINDS = {
        text: { type: :string, format: '@' }, time: { type: :time, format: 'dd mmm yyyy, hh:mm' },
        int: { type: :integer, format: '#,##0' }, pct: { type: :float, format: '0%' },
        duration: { type: :float, format: '[h]:mm' }
      }.freeze

      Column = Struct.new(:title, :width, :kind)

      attr_reader :package

      def initialize(package)
        @package = package
        @styles = {}
        @names = []
      end

      # A unique, Excel-legal sheet name (31 chars max, none of : \\ / ? * [ ]).
      def claim_name(name)
        base = name.to_s.gsub(%r{[:\\/?*\[\]]}, '-').strip[0, 31].presence || 'Sheet'
        candidate = base
        suffix = 2
        while @names.include?(candidate)
          candidate = "#{base[0, 31 - suffix.to_s.length - 3]} (#{suffix})"
          suffix += 1
        end
        @names << candidate
        candidate
      end

      def style(**attrs)
        @styles[attrs] ||= package.workbook.styles.add_style(
          { sz: 10, fg_color: INK, alignment: { vertical: :center } }.merge(attrs)
        )
      end

      def border
        { style: :thin, color: BORDER, edges: %i[top bottom left right] }
      end

      # A data cell style: kind (number format), zebra stripe and tone colour.
      def cell_style(kind, alt: false, tone: nil)
        fill, ink = TONES[tone]
        alignment = { vertical: :center, wrap_text: kind == :text }
        alignment[:horizontal] = :center if tone
        style(format_code: KINDS.fetch(kind)[:format], border: border, b: tone.present?,
              bg_color: fill || (alt ? LIGHT : WHITE), fg_color: ink || INK, alignment: alignment)
      end

      def banner(sheet, title, subtitle, span)
        sheet.add_row [title], style: style(sz: 16, b: true, fg_color: WHITE, bg_color: NAVY,
                                            alignment: { vertical: :center, indent: 1 }), height: 30
        sheet.merge_cells("A1:#{Axlsx.col_ref(span - 1)}1")
        sheet.add_row [subtitle], style: style(sz: 10, i: true, fg_color: MUTED, alignment: { vertical: :center, wrap_text: true }),
                                  height: 32
        sheet.merge_cells("A2:#{Axlsx.col_ref(span - 1)}2")
        sheet.add_row []
      end

      # One sheet: banner, header row, striped rows, filter and frozen header.
      # Returns [sheet, first_data_row, last_data_row] (1-based, for charts).
      def table(name, title:, subtitle:, columns:, rows:, tab: BLUE, empty: 'Nothing to report here.')
        sheet = package.workbook.add_worksheet(name: name)
        sheet.sheet_pr.tab_color = tab
        banner(sheet, title, subtitle, columns.size)
        header = style(b: true, fg_color: WHITE, bg_color: BLUE, border: border,
                       alignment: { vertical: :center, horizontal: :center, wrap_text: true })
        sheet.add_row columns.map(&:title), style: header, height: 24
        rows.each_with_index { |row, index| add_data_row(sheet, columns, row, index.odd?) }
        last = sheet.rows.size
        if rows.empty?
          sheet.add_row [empty], style: style(i: true, fg_color: MUTED)
          sheet.merge_cells("A#{sheet.rows.size}:#{Axlsx.col_ref(columns.size - 1)}#{sheet.rows.size}")
        else
          sheet.auto_filter = "A4:#{Axlsx.col_ref(columns.size - 1)}#{last}"
        end
        # Set after the rows: adding a long cell would otherwise widen the column.
        sheet.column_widths(*columns.map(&:width))
        sheet.sheet_view.pane { |pane| pane.top_left_cell = 'A5'; pane.state = :frozen; pane.y_split = 4 }
        sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
        [sheet, 5, last]
      end

      private

      def add_data_row(sheet, columns, row, alt)
        cells = row.each_with_index.map do |cell, index|
          value, tone = cell.is_a?(Array) ? cell : [cell, nil]
          [value, cell_style(columns[index].kind, alt: alt, tone: tone)]
        end
        sheet.add_row cells.map(&:first), style: cells.map(&:last),
                                          types: columns.map { |column| KINDS.fetch(column.kind)[:type] }
      end
    end
  end
end
