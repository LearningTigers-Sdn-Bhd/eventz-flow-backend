require 'caxlsx'

module PeopleCounter
  # One day of people-counter data as an Excel workbook an organizer can read
  # without help: headline tiles, each level and hall against its capacity, and
  # the day hour by hour (or 15 minutes by 15 minutes). Built from the same
  # EventAnalytics and EventHeadcount reads as the panel, so figures match it.
  # Look and feel come from the RFID report's SheetKit.
  class ReportWorkbook
    Kit = Rfid::ReportWorkbook::SheetKit

    LAST_COL = 8 # index of column I; column A is a margin on the Summary sheet
    NEAR_FULL_PERCENT = 90

    STATUS_CHIPS = {
      'ok' => ['Counting', :good], 'unlinked' => ['No counter linked', :warn],
      'not_found' => ['Counter not found', :bad], 'unavailable' => ['Counter unreachable', :bad]
    }.freeze

    SHEETS = {
      days: ['By Day', 'Every event day side by side: arrivals, departures and the peak crowd.'],
      halls_by_day: ['Halls by Day', 'The same, hall by hall. Use the filter to follow one hall across the days.'],
      traffic: ['Event Traffic', 'The selected day, slot by slot: arrivals, departures and people inside.'],
      halls: ['Hall Detail', 'Every hall, slot by slot. Use the filter on Hall or Level to focus.']
    }.freeze

    def initialize(event, date: nil, bucket: 60, now: Time.current, client: nil)
      @event = event
      @now = now
      @data = EventAnalytics.new(event, date: date, bucket: bucket, client: client).call
      @headcount = EventHeadcount.new(event, client: client).call
      @days = EventDays.new(event, client: client).call[:days]
      @step = @data[:bucket] == 15 ? '15 minutes' : 'hour'
    end

    def filename
      "people-counts-#{@event.id}-#{@data[:date]}.xlsx"
    end

    # The .xlsx file contents.
    def call
      package = Axlsx::Package.new(author: 'EventzFlow')
      @kit = Kit.new(package)
      @names = { summary: @kit.claim_name('Summary') }
      SHEETS.each { |key, (name, _)| @names[key] = @kit.claim_name(name) }
      summary_sheet(package)
      days_sheet
      halls_by_day_sheet
      traffic_sheet
      hall_sheet
      package.to_stream.read
    end

    private

    def col(title, width, kind = :text)
      Kit::Column.new(title, width, kind)
    end

    def clock(iso)
      iso && iso[11, 5]
    end

    def slot(iso)
      iso && Time.zone.parse(iso)
    end

    def day_label
      Date.iso8601(@data[:date]).strftime('%A, %d %B %Y')
    end

    def entries(points)
      points.sum { |p| p[:in] }
    end

    def exits(points)
      points.sum { |p| p[:out] }
    end

    def closing(points)
      points.last&.dig(:occupancy)
    end

    def capacity_of(rows, key, value)
      rows.find { |row| row[key] == value }&.dig(:capacity)
    end

    # How a peak compares with capacity, as a coloured chip.
    def capacity_chip(peak, capacity)
      return ['No capacity set', :info] unless capacity&.positive? && peak

      percent = peak * 100.0 / capacity
      return ['Over capacity', :bad] if percent > 100
      return ['Nearly full', :warn] if percent >= NEAR_FULL_PERCENT

      ['Within capacity', :good]
    end

    # ---- Summary ----------------------------------------------------------

    def summary_sheet(package)
      @sheet = package.workbook.add_worksheet(name: @names[:summary])
      @sheet.sheet_pr.tab_color = Kit::NAVY
      @sheet.sheet_view.show_grid_lines = false
      banner
      tiles
      levels_table
      halls_table
      guide
      # Set after the rows: adding a long cell would otherwise widen the column.
      @sheet.column_widths 2, 22, 18, 14, 14, 14, 14, 14, 20
      @sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
    end

    # Adds a row starting in column B; returns its 1-based row number.
    def row(values, style:, height: nil)
      @sheet.add_row [nil, *values], style: [nil, *Array(style)], height: height
      @sheet.rows.size
    end

    def merged(number, from, to)
      @sheet.merge_cells("#{Axlsx.col_ref(from)}#{number}:#{Axlsx.col_ref(to)}#{number}")
    end

    def section(title)
      @sheet.add_row []
      number = row([title] + [nil] * 7, style: @kit.style(sz: 12, b: true, fg_color: Kit::NAVY,
                                                            border: { style: :medium, color: Kit::NAVY, edges: [:bottom] }))
      merged(number, 1, LAST_COL)
    end

    def plain(text)
      number = row([text] + [nil] * 7, style: @kit.style(i: true, fg_color: Kit::MUTED))
      merged(number, 1, LAST_COL)
    end

    def banner
      number = row([@event.title] + [nil] * 7,
                   style: @kit.style(sz: 20, b: true, fg_color: Kit::WHITE, bg_color: Kit::NAVY,
                                     alignment: { vertical: :center, indent: 1 }), height: 40)
      merged(number, 1, LAST_COL)
      text = "People counter report  •  #{day_label}  •  Generated #{@now.strftime('%d %b %Y, %I:%M %p')}"
      number = row([text] + [nil] * 7,
                   style: @kit.style(sz: 10, i: true, fg_color: Kit::WHITE, bg_color: Kit::BLUE,
                                     alignment: { vertical: :center, indent: 1 }), height: 20)
      merged(number, 1, LAST_COL)
    end

    def tiles
      event = @data[:event]
      stats = event[:stats]
      whole = @headcount[:event]
      section('The day at a glance')
      tile_row([['PEAK CROWD', stats&.dig(:peak, :occupancy), stats ? "at #{clock(stats[:peak][:at])}" : 'No movement yet', '2766EC'],
                ['CAME IN', entries(event[:points]), 'On this day', '16A34A'],
                ['LEFT', exits(event[:points]), 'On this day', 'D97706'],
                ['BUSIEST HOUR', stats&.dig(:busiest_entry_hour, :in), busiest_hint(stats), '2766EC']])
      @sheet.add_row []
      tile_row([['INSIDE AT LAST READING', closing(event[:points]), 'People still inside', '16A34A'],
                ['TOTAL CAPACITY', whole[:capacity], 'All counted halls added up', '6B7280'],
                ['CAME IN, WHOLE EVENT', whole[:in_event], 'Event start to end', '2766EC'],
                ['LEFT, WHOLE EVENT', whole[:out_event], 'Event start to end', '6B7280']])
    end

    def busiest_hint(stats)
      return 'Arrivals in the busiest hour' unless stats

      hour = stats[:busiest_entry_hour][:at]
      "Arrivals #{clock(hour)}–#{format('%02d', (hour[11, 2].to_i + 1) % 24)}:00"
    end

    def tile_row(tiles)
      { label: nil, value: 38, hint: nil }.each do |kind, height|
        cells = tiles.flat_map { |label, value, hint, _| [{ label: label, value: value, hint: hint }[kind], nil] }
        styles = tiles.flat_map { |*, color| [tile_style(kind, color)] * 2 }
        number = row(cells, style: styles, height: height)
        tiles.each_index { |index| merged(number, 1 + index * 2, 2 + index * 2) }
      end
    end

    def tile_style(kind, color)
      fill = Kit::LIGHT
      case kind
      when :label
        @kit.style(sz: 9, b: true, fg_color: Kit::MUTED, bg_color: fill,
                   alignment: { horizontal: :center, vertical: :bottom },
                   border: { style: :thick, color: "FF#{color}", edges: [:top] })
      when :value
        @kit.style(sz: 24, b: true, fg_color: "FF#{color}", bg_color: fill, format_code: '#,##0',
                   alignment: { horizontal: :center, vertical: :center })
      else
        @kit.style(sz: 9, fg_color: Kit::MUTED, bg_color: fill, alignment: { horizontal: :center, vertical: :top })
      end
    end

    def header(titles)
      style = @kit.style(b: true, fg_color: Kit::WHITE, bg_color: Kit::BLUE, border: @kit.border,
                         alignment: { horizontal: :center, vertical: :center, wrap_text: true })
      row(titles, style: Array.new(titles.size, style), height: 28)
    end

    # A cell is a plain value or [value, tone] for a coloured chip.
    def body(values, kinds, alt)
      cells = values.map { |value| value.is_a?(Array) ? value : [value, nil] }
      styles = cells.each_with_index.map { |(_, tone), i| @kit.cell_style(kinds[i], alt: alt, tone: tone) }
      row(cells.map(&:first), style: styles)
    end

    def levels_table
      section('By level')
      return plain('No levels yet.') if @data[:levels].empty?

      header(['Level', 'Capacity', 'Peak crowd', 'Peak at', 'Came in', 'Left', 'Inside at last reading', 'Peak vs capacity'])
      @data[:levels].each_with_index do |level, index|
        stats = level[:stats]
        cap = capacity_of(@headcount[:levels], :floor, level[:floor])
        peak = stats&.dig(:peak, :occupancy)
        body([level[:floor].presence || 'No level set', cap, peak, clock(stats&.dig(:peak, :at)), entries(level[:points]),
              exits(level[:points]), closing(level[:points]), capacity_chip(peak, cap)],
             %i[text int int text int int int text], index.odd?)
      end
    end

    def halls_table
      section('By hall')
      header(['Hall', 'Level', 'Capacity', 'Peak crowd', 'Came in', 'Left', 'Counter', 'Peak vs capacity'])
      @data[:halls].each_with_index do |hall, index|
        stats = hall[:stats]
        cap = capacity_of(@headcount[:halls], :id, hall[:id])
        peak = stats&.dig(:peak, :occupancy)
        body([hall[:name], hall[:floor].presence || 'No level set', cap, peak, entries(hall[:points]), exits(hall[:points]),
              STATUS_CHIPS.fetch(hall[:status], [hall[:status].to_s, :info]), capacity_chip(peak, cap)],
             %i[text text int int int int text text], index.odd?)
      end
      plain('Peak crowd is the most people inside at once on this day, measured in 15-minute counts.')
    end

    def guide
      section('What is in this workbook')
      SHEETS.each do |key, (_, text)|
        name = @names[key]
        number = row([name, text] + [nil] * 6, style: [@kit.style(b: true, fg_color: Kit::BLUE),
                                                        @kit.style(fg_color: Kit::MUTED)] + [@kit.style] * 6)
        merged(number, 2, LAST_COL)
        @sheet.add_hyperlink location: "'#{name.gsub("'", "''")}'!A1", ref: "B#{number}"
      end
    end

    # ---- Detail sheets ----------------------------------------------------

    def short_day(iso)
      Date.iso8601(iso).strftime('%a, %d %b %Y')
    end

    def hour_range(iso)
      iso && "#{clock(iso)}–#{format('%02d', (iso[11, 2].to_i + 1) % 24)}:00"
    end

    def days_sheet
      rows = @days.map do |day|
        [short_day(day[:date]), day[:entries], day[:exits], day[:peak]&.dig(:occupancy), clock(day[:peak]&.dig(:at)),
         day[:busiest_entry_hour]&.dig(:in), hour_range(day[:busiest_entry_hour]&.dig(:at)), day[:closing]]
      end
      sheet, first, last = @kit.table(@names[:days], title: 'Day by day',
                                      subtitle: 'Each event day up to today. Peak crowd is the most people inside at once that day.',
                                      columns: [col('Day', 22), col('Came in', 12, :int), col('Left', 12, :int),
                                                col('Peak crowd', 12, :int), col('Peak at', 10), col('Busiest hour arrivals', 14, :int),
                                                col('Busiest hour', 14), col('Inside at close', 14, :int)],
                                      rows: rows, tab: 'FF2766EC', empty: 'No event day has been counted yet.')
      return if rows.empty?

      sheet.add_chart(Axlsx::BarChart, start_at: 'J4', end_at: 'S22', title: 'Came in and left, per day', bar_dir: :col) do |chart|
        chart.add_series data: sheet["B#{first}:B#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Came in', color: '16A34A'
        chart.add_series data: sheet["C#{first}:C#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Left', color: 'D97706'
        chart.gap_width = 40
      end
    end

    def halls_by_day_sheet
      rows = @days.flat_map do |day|
        day[:halls].map do |hall|
          [short_day(day[:date]), hall[:floor].presence || 'No level set', hall[:name], hall[:entries], hall[:exits],
           hall[:peak]&.dig(:occupancy), clock(hall[:peak]&.dig(:at))]
        end
      end
      @kit.table(@names[:halls_by_day], title: 'Halls by day',
                 subtitle: 'One row per hall per event day. Halls with no counter linked show zeros.',
                 columns: [col('Day', 22), col('Level', 18), col('Hall', 24), col('Came in', 12, :int), col('Left', 12, :int),
                           col('Peak crowd', 12, :int), col('Peak at', 10)],
                 rows: rows, tab: 'FF7C3AED', empty: 'No event day has been counted yet.')
    end

    def traffic_sheet
      rows = @data[:event][:points].map { |p| [slot(p[:bucket]), p[:in], p[:out], p[:in] - p[:out], p[:occupancy]] }
      sheet, first, last = @kit.table(@names[:traffic], title: 'Event traffic',
                                      subtitle: "#{day_label}. Per #{@step}: people who came in, left, and were inside at the end of it.",
                                      columns: [col('Time slot', 20, :time), col('Came in', 12, :int), col('Left', 12, :int),
                                                col('Net', 12, :int), col('Inside', 12, :int)],
                                      rows: rows, tab: 'FF0EA5E9', empty: 'No gate activity on this day.')
      add_traffic_charts(sheet, first, last) unless rows.empty?
    end

    def add_traffic_charts(sheet, first, last)
      sheet.add_chart(Axlsx::LineChart, start_at: 'G4', end_at: 'P21', title: 'People inside') do |chart|
        chart.add_series data: sheet["E#{first}:E#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Inside',
                         color: Kit::BLUE.delete_prefix('FF')
        chart.show_legend = false
      end
      sheet.add_chart(Axlsx::BarChart, start_at: 'G23', end_at: 'P40', title: 'Came in and left', bar_dir: :col) do |chart|
        chart.add_series data: sheet["B#{first}:B#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Came in', color: '16A34A'
        chart.add_series data: sheet["C#{first}:C#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Left', color: 'D97706'
        chart.gap_width = 40
      end
    end

    def hall_sheet
      rows = @data[:halls].flat_map do |hall|
        hall[:points].map do |p|
          [hall[:floor].presence || 'No level set', hall[:name], slot(p[:bucket]), p[:in], p[:out], p[:in] - p[:out], p[:occupancy]]
        end
      end
      @kit.table(@names[:halls], title: 'Hall detail',
                 subtitle: "#{day_label}. One row per hall per #{@step}. Halls with no counter linked have no rows.",
                 columns: [col('Level', 18), col('Hall', 24), col('Time slot', 20, :time), col('Came in', 12, :int),
                           col('Left', 12, :int), col('Net', 12, :int), col('Inside', 12, :int)],
                 rows: rows, tab: 'FF16A34A', empty: 'No hall has counts on this day.')
    end
  end
end
