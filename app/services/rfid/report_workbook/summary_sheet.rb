module Rfid
  class ReportWorkbook
    # The first sheet a client sees: the dashboard figures as big tiles, the
    # attendance funnel with a chart, how each session went, and a guide to the
    # other sheets. Columns B..I carry the content; A is a margin.
    class SummarySheet
      LAST_COL = 8 # index of column I

      GUIDE = [
        ['E-Certificate', 'Who qualifies for an e-certificate (shown when required sessions are set).'],
        ['No Gate Read', 'Checked in at the desk but never read by a gate. Sticker-linked guests first.'],
        ['Guest Visits', 'Total time in the hall for each guest, all visits added together.'],
        ['Traffic', 'Arrivals, departures and guests inside over time.']
      ].freeze

      def initialize(kit, event:, now:, summary:, sessions:, types:, sheet_names:)
        @kit = kit
        @event = event
        @now = now
        @s = summary
        @sessions = sessions
        @types = types
        @sheet_names = sheet_names
      end

      def build
        @sheet = @kit.package.workbook.add_worksheet(name: 'Summary')
        @sheet.sheet_pr.tab_color = SheetKit::NAVY
        @sheet.sheet_view.show_grid_lines = false
        banner
        tiles
        funnel
        sessions_table
        types_table
        guide
        # Set after the rows: adding a long cell would otherwise widen the column.
        @sheet.column_widths 2, *Array.new(8, 17), 17
        @sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      end

      private

      # Adds a row starting in column B; returns its 1-based row number.
      def row(values, style:, height: nil)
        @sheet.add_row [nil, *values], style: [nil, *Array(style)], height: height
        @sheet.rows.size
      end

      def merged(row_number, from, to)
        @sheet.merge_cells("#{Axlsx.col_ref(from)}#{row_number}:#{Axlsx.col_ref(to)}#{row_number}")
      end

      def section(title)
        @sheet.add_row []
        number = row([title] + [nil] * 7, style: @kit.style(sz: 12, b: true, fg_color: SheetKit::NAVY,
                                                              border: { style: :medium, color: SheetKit::NAVY, edges: [:bottom] }))
        merged(number, 1, LAST_COL)
      end

      def banner
        number = row([@event.title] + [nil] * 7,
                     style: @kit.style(sz: 20, b: true, fg_color: SheetKit::WHITE, bg_color: SheetKit::NAVY,
                                       alignment: { vertical: :center, indent: 1 }), height: 40)
        merged(number, 1, LAST_COL)
        number = row(["Attendance report  •  Generated #{@now.strftime('%d %b %Y, %I:%M %p')}"] + [nil] * 7,
                     style: @kit.style(sz: 10, i: true, fg_color: SheetKit::WHITE, bg_color: SheetKit::BLUE,
                                       alignment: { vertical: :center, indent: 1 }), height: 20)
        merged(number, 1, LAST_COL)
      end

      # Four tiles per row, each two columns wide: label, big number, hint.
      def tiles
        section('Venue at a glance')
        registered = [@s[:registered], 1].max
        pct = ->(count) { "#{(count * 100.0 / registered).round}% of registered" }
        tile_row([['REGISTERED', @s[:registered], 'Paid, non-cancelled tickets', '2766EC'],
                  ['CHECKED IN AT DESK', @s[:checked_in], pct.call(@s[:checked_in]), '2766EC'],
                  ['PASSED A GATE', @s[:gate_scanned], pct.call(@s[:gate_scanned]), '16A34A'],
                  ['INSIDE RIGHT NOW', @s[:inside], 'Guests in the hall', '16A34A']])
        @sheet.add_row []
        tile_row([['NOT ARRIVED', @s[:not_arrived], 'Registered, yet to check in', '6B7280'],
                  ['NO GATE READ', @s[:missed_scans].values.sum, 'Checked in, never read by a gate', 'D97706'],
                  ['OUTSIDE RIGHT NOW', @s[:outside], 'Entered earlier, since left', 'D97706'],
                  ['INSIDE OVER 6 HOURS', @s[:likely_gone], 'Probably left without scanning out', '6B7280']])
      end

      def tile_row(tiles)
        { label: nil, value: 38, hint: nil }.each do |kind, height|
          cells = tiles.flat_map { |label, value, hint, _color| [{ label: label, value: value, hint: hint }[kind], nil] }
          styles = tiles.flat_map { |*, color| [tile_style(kind, color)] * 2 }
          number = row(cells, style: styles, height: height)
          tiles.each_index { |index| merged(number, 1 + index * 2, 2 + index * 2) }
        end
      end

      def tile_style(kind, color)
        fill = SheetKit::LIGHT
        case kind
        when :label
          @kit.style(sz: 9, b: true, fg_color: SheetKit::MUTED, bg_color: fill,
                     alignment: { horizontal: :center, vertical: :bottom },
                     border: { style: :thick, color: "FF#{color}", edges: [:top] })
        when :value
          @kit.style(sz: 24, b: true, fg_color: "FF#{color}", bg_color: fill, format_code: '#,##0',
                     alignment: { horizontal: :center, vertical: :center })
        else
          @kit.style(sz: 9, fg_color: SheetKit::MUTED, bg_color: fill,
                     alignment: { horizontal: :center, vertical: :top })
        end
      end

      def header(titles)
        style = @kit.style(b: true, fg_color: SheetKit::WHITE, bg_color: SheetKit::BLUE, border: @kit.border,
                           alignment: { horizontal: :center, vertical: :center, wrap_text: true })
        row(titles, style: Array.new(titles.size, style), height: 28)
      end

      def body(values, kinds, alt)
        row(values, style: kinds.map { |kind| @kit.cell_style(kind, alt: alt) })
      end

      def funnel
        section('Attendance funnel')
        header(['Stage', nil, 'Guests', '% of registered'])
        merged(@sheet.rows.size, 1, 2)
        base = [@s[:registered], 1].max
        stages = [['Registered', @s[:registered]], ['Checked in at the desk', @s[:checked_in]],
                  ['Passed a gate', @s[:gate_scanned]], ['Inside right now', @s[:inside]],
                  ['Outside right now', @s[:outside]]]
        first = @sheet.rows.size + 1
        stages.each_with_index do |(label, count), index|
          merged(body([label, nil, count, count.to_f / base], %i[text text int pct], index.odd?), 1, 2)
        end
        last = @sheet.rows.size
        # Column F stays empty as a gutter; the chart sits in G..I.
        @sheet.add_chart(Axlsx::BarChart, start_at: "G#{first - 1}", end_at: "J#{last + 3}", bar_dir: :bar,
                                          title: 'Where guests are') do |chart|
          chart.add_series data: @sheet["D#{first}:D#{last}"], labels: @sheet["B#{first}:B#{last}"], title: 'Guests',
                           colors: %w[2766EC 2766EC 16A34A 16A34A D97706]
          chart.show_legend = false
          chart.gap_width = 45
          chart.valAxis.gridlines = false
          chart.valAxis.tick_lbl_pos = :none
          chart.catAxis.scaling.orientation = :maxMin
          chart.d_lbls.show_val = true
        end
        4.times { @sheet.add_row [] }
      end

      def sessions_table
        section('Sessions')
        return plain('No sessions have been set up for this event.') if @sessions.empty?

        header(['Session', 'When', 'Type', 'Status', 'In the hall', 'Attended', 'Not enough time', 'Did not come'])
        @sessions.each_with_index do |s, index|
          window = "#{Time.zone.parse(s[:starts_at]).strftime('%d %b, %H:%M')} – " \
                   "#{Time.zone.parse(s[:ends_at]).strftime('%H:%M')}"
          body([s[:name], window, s[:mandatory] ? 'Required' : 'Optional', s[:status].capitalize, s[:present],
                s[:attended], s[:present] - s[:attended], [@s[:registered] - s[:present], 0].max],
               %i[text text text text int int int int], index.odd?)
        end
        plain("Attended = in the hall for at least #{@event.rfid_attendance_percent}% of the session.", muted: true)
      end

      def types_table
        section('By ticket type')
        return plain('No ticket types.') if @types.empty?

        header(['Ticket type', nil, 'Registered', 'Checked in', 'Passed a gate', 'Inside now', 'No gate read'])
        merged(@sheet.rows.size, 1, 2)
        @types.each_with_index do |(name, *counts), index|
          merged(body([name, nil, *counts], %i[text text int int int int int], index.odd?), 1, 2)
        end
      end

      def guide
        section('What is in this workbook')
        entries = @sessions.map { |s| [@sheet_names[s[:id]], "Who attended \"#{s[:name]}\" and who stayed too short a time."] }
        (entries + GUIDE).each do |name, text|
          number = row([name, text] + [nil] * 6, style: [@kit.style(b: true, fg_color: SheetKit::BLUE),
                                                          @kit.style(fg_color: SheetKit::MUTED)] + [@kit.style] * 6)
          merged(number, 2, LAST_COL)
          @sheet.add_hyperlink location: "'#{name.gsub("'", "''")}'!A1", ref: "B#{number}"
        end
      end

      def plain(text, muted: false)
        number = row([text] + [nil] * 7, style: @kit.style(i: true, fg_color: SheetKit::MUTED, sz: muted ? 9 : 10))
        merged(number, 1, LAST_COL)
      end
    end
  end
end
