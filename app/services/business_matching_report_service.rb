# frozen_string_literal: true

class BusinessMatchingReportService
  COL_WIDTHS = [
    12, # Table
    28, # Seller / Session
    22, # Host
    22, # Buyer Name
    26, # Buyer Email
    16, # Buyer Phone
    16, # Date
    14, # Time
    14, # Status
    14, # Attendance
    20, # Potential Deal Value
    30, # Host Comment
    32, # Description
    32, # Sourcing Intent
    32  # Capabilities
  ].freeze

  ROW_TYPES = [
    :string, # Table
    :string, # Seller / Session
    :string, # Host
    :string, # Buyer Name
    :string, # Buyer Email
    :string, # Buyer Phone (force string to prevent scientific notation)
    :string, # Date
    :string, # Time
    :string, # Status
    :string, # Attendance
    :float,  # Potential Deal Value
    :string, # Host Comment
    :string, # Description
    :string, # Sourcing Intent
    :string  # Capabilities
  ].freeze

  def initialize(bookings, event_title = "Business Matching Report")
    @bookings = bookings || []
    @event_title = event_title
  end

  def generate_xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    styles = build_styles(workbook)

    # 1. Master sheet containing all bookings
    add_master_sheet(workbook, styles)

    # 2. Buyer Schedule Matrix sheets (cross-tab of buyers x time slots)
    add_buyer_matrix_sheets(workbook, styles)

    # 3. Executive Summary sheet with KPI cards & seller breakdown
    add_summary_sheet(workbook, styles)

    # 4. Individual session tabs (when there are multiple sessions)
    add_session_sheets(workbook, styles)

    package.to_stream.read
  end

  private

  attr_reader :bookings, :event_title

  def headers
    [
      "Table",
      "Seller / Session",
      "Host",
      "Buyer Name",
      "Buyer Email",
      "Buyer Phone",
      "Date",
      "Time",
      "Status",
      "Attendance",
      "Potential Deal Value",
      "Host Comment",
      "Description",
      "Sourcing Intent",
      "Capabilities"
    ]
  end

  def row_data(booking)
    [
      booking[:location].presence || "-",
      booking[:event_title].presence || "Matchmaking Session",
      booking[:host_name].presence || "-",
      booking[:name].to_s,
      booking[:email].to_s,
      booking[:phone].to_s,
      booking[:booking_date].to_s,
      booking[:booking_time].to_s,
      booking[:status].to_s,
      booking[:attendance].presence || "-",
      booking[:potential_deal_value].to_f,
      booking[:host_comment].to_s,
      booking[:booker_description].to_s,
      booking[:booker_sourcing_intent].to_s,
      booking[:booker_capabilities].to_s
    ]
  end

  def sort_bookings(list)
    list.sort_by do |b|
      date = parse_date(b[:booking_date])
      minutes = slot_minutes(b[:booking_time])
      table_num = b[:location].to_s.gsub(/\D/, '').to_i
      table_sort = table_num.zero? ? 999_999 : table_num

      # Order chronologically: Date -> Time of day -> Table number -> Session -> Name
      [date, minutes, table_sort, b[:event_title].to_s.downcase, b[:name].to_s.downcase]
    end
  end

  def parse_date(date_str)
    return Date.new(9999, 12, 31) if date_str.blank?

    Date.parse(date_str.to_s)
  rescue ArgumentError
    Date.new(9999, 12, 31)
  end

  def slot_minutes(booking_time)
    return 24 * 60 if booking_time.blank?

    t = Time.strptime(booking_time.to_s.strip, "%I:%M %p")
    t.hour * 60 + t.min
  rescue ArgumentError
    24 * 60
  end

  def add_master_sheet(workbook, styles)
    workbook.add_worksheet(name: "All Bookings") do |sheet|
      sheet.add_row headers, style: styles[:header], height: 28

      sorted = sort_bookings(bookings)
      sorted.each do |booking|
        sheet.add_row row_data(booking), style: row_style_for(booking, styles), types: ROW_TYPES, height: 22
      end

      sheet.column_widths(*COL_WIDTHS)
      setup_sheet_view(sheet, sorted.size + 1, headers.size)
    end
  end

  def add_session_sheets(workbook, styles)
    grouped = bookings.group_by { |b| b[:event_title].presence || "General" }
    return if grouped.size <= 1 # If only 1 session, Master Sheet is sufficient

    used_names = Set.new(workbook.worksheets.map(&:name))

    grouped.each do |group_title, session_bookings|
      next if session_bookings.empty?

      sheet_name = sanitize_sheet_name(group_title, used_names)
      used_names.add(sheet_name)

      workbook.add_worksheet(name: sheet_name) do |sheet|
        sheet.add_row headers, style: styles[:header], height: 28

        sorted = sort_bookings(session_bookings)
        sorted.each do |booking|
          sheet.add_row row_data(booking), style: row_style_for(booking, styles), types: ROW_TYPES, height: 22
        end

        sheet.column_widths(*COL_WIDTHS)
        setup_sheet_view(sheet, sorted.size + 1, headers.size)
      end
    end
  end

  def add_buyer_matrix_sheets(workbook, styles)
    return if bookings.empty?

    used_names = Set.new(workbook.worksheets.map(&:name))
    dates = bookings.map { |b| b[:booking_date].presence || "General" }.uniq

    dates.each do |date_val|
      date_bookings = bookings.select { |b| (b[:booking_date].presence || "General") == date_val }
      next if date_bookings.empty?

      sheet_name_base = dates.size > 1 ? "Matrix - #{date_val}" : "Buyer Matrix"
      sheet_name = sanitize_sheet_name(sheet_name_base, used_names)
      used_names.add(sheet_name)

      # Extract unique time slots for this date
      time_slots = date_bookings.map { |b| b[:booking_time].to_s.strip }.reject(&:blank?).uniq
      time_slots = time_slots.sort_by { |t| slot_minutes(t) }
      next if time_slots.empty?

      first_duration = date_bookings.map { |b| b[:duration].to_i }.find(&:positive?) || 30
      matrix_headers = ["Buyer Name", "Buyer Email", "Buyer Phone"] + time_slots.map { |t| time_slot_label(t, first_duration) }

      # Extract unique buyers
      buyers = date_bookings.map do |b|
        {
          name: b[:name].to_s.strip,
          email: b[:email].to_s.strip,
          phone: b[:phone].to_s.strip
        }
      end.uniq { |b| [b[:email].downcase, b[:name].downcase] }
      buyers = buyers.sort_by { |b| b[:name].downcase }

      # Lookup table: [buyer_email, slot_minutes] -> booking
      lookup = {}
      date_bookings.each do |b|
        key = [b[:email].to_s.downcase.strip, slot_minutes(b[:booking_time])]
        lookup[key] = b
      end

      workbook.add_worksheet(name: sheet_name) do |sheet|
        sheet.add_row matrix_headers, style: styles[:header], height: 28

        buyers.each do |buyer|
          row = [buyer[:name], buyer[:email], buyer[:phone]]
          row_styles = [styles[:cell], styles[:cell], styles[:cell_phone]]
          types = [:string, :string, :string]

          time_slots.each do |slot|
            b_match = lookup[[buyer[:email].downcase, slot_minutes(slot)]]
            if b_match
              seller_info = b_match[:location].present? ? "[#{b_match[:location]}] #{b_match[:event_title]}" : b_match[:event_title].to_s
              row << seller_info
              row_styles << styles[:matrix_filled]
            else
              row << "-"
              row_styles << styles[:matrix_empty]
            end
            types << :string
          end

          sheet.add_row row, style: row_styles, types: types, height: 24
        end

        col_widths = [24, 28, 16] + Array.new(time_slots.size, 26)
        sheet.column_widths(*col_widths)

        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = "D2"
          pane.state = :frozen_split
          pane.x_split = 3
          pane.y_split = 1
        end

        if buyers.any?
          last_col = Axlsx.col_ref(matrix_headers.size - 1)
          sheet.auto_filter = "A1:#{last_col}#{buyers.size + 1}"
        end
      end
    end
  end

  def time_slot_label(time_str, duration = 30)
    t = Time.strptime(time_str.to_s.strip, "%I:%M %p")
    end_t = t + (duration || 30).minutes
    "#{t.strftime('%-I:%M %p')} – #{end_t.strftime('%-I:%M %p')}"
  rescue ArgumentError
    time_str
  end

  def add_summary_sheet(workbook, styles)
    workbook.add_worksheet(name: "Summary") do |sheet|
      # Title banner
      sheet.add_row ["#{event_title} — Executive Summary"], style: styles[:summary_title], height: 30
      sheet.add_row ["Generated on #{Time.current.strftime('%-d %B %Y, %I:%M %p')} | Total Bookings: #{bookings.size}"], style: styles[:summary_subtitle], height: 20
      sheet.add_row []

      # KPI Summary Block
      kpi_headers = ["Total Bookings", "Confirmed / Approved", "Pending", "Cancelled", "Attended", "Total Pipeline Value"]
      confirmed_count = bookings.count { |b| %w[confirmed approved].include?(b[:status].to_s.downcase) }
      pending_count = bookings.count { |b| b[:status].to_s.downcase == 'pending' }
      cancelled_count = bookings.count { |b| %w[cancelled absent].include?(b[:status].to_s.downcase) }
      attended_count = bookings.count { |b| b[:attendance].to_s.downcase.in?(%w[attended present yes]) }
      total_deal_val = bookings.sum { |b| b[:potential_deal_value].to_f rescue 0.0 }

      sheet.add_row kpi_headers, style: styles[:kpi_header], height: 22
      sheet.add_row [
        bookings.size,
        confirmed_count,
        pending_count,
        cancelled_count,
        attended_count,
        total_deal_val
      ], style: [
        styles[:kpi_val],
        styles[:kpi_val_green],
        styles[:kpi_val_amber],
        styles[:kpi_val_red],
        styles[:kpi_val],
        styles[:kpi_val_currency]
      ], height: 28
      sheet.add_row []

      # Breakdown by Seller / Table
      sheet.add_row ["Breakdown by Seller / Table"], style: styles[:section_header], height: 24
      breakdown_headers = ["Table", "Seller / Session", "Host", "Total Bookings", "Confirmed", "Pending", "Attended", "Total Pipeline Value"]
      sheet.add_row breakdown_headers, style: styles[:summary_table_header], height: 24

      grouped_by_session = bookings.group_by { |b| [b[:location].presence || "-", b[:event_title].presence || "General", b[:host_name].presence || "-"] }
      grouped_by_session.sort_by { |k, _| k[0] }.each do |(location, title, host), s_bookings|
        s_total = s_bookings.size
        s_conf = s_bookings.count { |b| %w[confirmed approved].include?(b[:status].to_s.downcase) }
        s_pend = s_bookings.count { |b| b[:status].to_s.downcase == 'pending' }
        s_att = s_bookings.count { |b| b[:attendance].to_s.downcase.in?(%w[attended present yes]) }
        s_deal = s_bookings.sum { |b| b[:potential_deal_value].to_f rescue 0.0 }

        sheet.add_row [
          location,
          title,
          host,
          s_total,
          s_conf,
          s_pend,
          s_att,
          s_deal
        ], style: [
          styles[:cell_center],
          styles[:cell],
          styles[:cell],
          styles[:cell_center],
          styles[:cell_center],
          styles[:cell_center],
          styles[:cell_center],
          styles[:cell_currency]
        ], height: 20
      end

      sheet.column_widths 14, 32, 24, 16, 16, 16, 16, 22
    end
  end

  def sanitize_sheet_name(raw_name, used_names)
    clean = raw_name.to_s.gsub(/[:\/?*\[\]]/, '').strip
    clean = "Session" if clean.blank?

    base = clean.truncate(31)
    name = base
    counter = 1

    while used_names.include?(name)
      suffix = "_#{counter}"
      name = "#{clean.truncate(31 - suffix.length)}#{suffix}"
      counter += 1
    end

    name
  end

  def setup_sheet_view(sheet, row_count, col_count)
    sheet.sheet_view.pane do |pane|
      pane.top_left_cell = "A2"
      pane.state = :frozen_split
      pane.y_split = 1
    end

    if row_count > 1
      last_col = Axlsx.col_ref(col_count - 1)
      sheet.auto_filter = "A1:#{last_col}#{row_count}"
    end
  end

  def row_style_for(booking, styles)
    status_style = case booking[:status].to_s.downcase
                   when "confirmed", "approved"
                     styles[:status_confirmed]
                   when "pending"
                     styles[:status_pending]
                   when "cancelled", "absent"
                     styles[:status_cancelled]
                   else
                     styles[:cell_center]
                   end

    [
      styles[:cell_center],   # Table
      styles[:cell],          # Seller
      styles[:cell],          # Host
      styles[:cell],          # Buyer Name
      styles[:cell],          # Buyer Email
      styles[:cell_phone],    # Buyer Phone
      styles[:cell_center],   # Date
      styles[:cell_center],   # Time
      status_style,           # Status
      styles[:cell_center],   # Attendance
      styles[:cell_currency], # Deal Value
      styles[:cell],          # Comment
      styles[:cell],          # Description
      styles[:cell],          # Sourcing Intent
      styles[:cell]           # Capabilities
    ]
  end

  def build_styles(workbook)
    wb_styles = workbook.styles

    {
      header: wb_styles.add_style(
        bg_color: "1E293B",
        fg_color: "FFFFFF",
        b: true,
        sz: 10,
        alignment: { horizontal: :center, vertical: :center, wrap_text: true }
      ),
      summary_title: wb_styles.add_style(
        bg_color: "0F172A",
        fg_color: "FFFFFF",
        b: true,
        sz: 13,
        alignment: { horizontal: :left, vertical: :center }
      ),
      summary_subtitle: wb_styles.add_style(
        fg_color: "64748B",
        sz: 9,
        italic: true,
        alignment: { horizontal: :left, vertical: :center }
      ),
      kpi_header: wb_styles.add_style(
        bg_color: "334155",
        fg_color: "FFFFFF",
        b: true,
        sz: 9,
        alignment: { horizontal: :center, vertical: :center }
      ),
      kpi_val: wb_styles.add_style(
        bg_color: "F8FAFC",
        fg_color: "0F172A",
        b: true,
        sz: 13,
        alignment: { horizontal: :center, vertical: :center }
      ),
      kpi_val_green: wb_styles.add_style(
        bg_color: "F8FAFC",
        fg_color: "15803D",
        b: true,
        sz: 13,
        alignment: { horizontal: :center, vertical: :center }
      ),
      kpi_val_amber: wb_styles.add_style(
        bg_color: "F8FAFC",
        fg_color: "B45309",
        b: true,
        sz: 13,
        alignment: { horizontal: :center, vertical: :center }
      ),
      kpi_val_red: wb_styles.add_style(
        bg_color: "F8FAFC",
        fg_color: "B91C1C",
        b: true,
        sz: 13,
        alignment: { horizontal: :center, vertical: :center }
      ),
      kpi_val_currency: wb_styles.add_style(
        bg_color: "F8FAFC",
        fg_color: "0F172A",
        b: true,
        sz: 13,
        format_code: "#,##0.00",
        alignment: { horizontal: :center, vertical: :center }
      ),
      section_header: wb_styles.add_style(
        fg_color: "0F172A",
        b: true,
        sz: 11,
        alignment: { horizontal: :left, vertical: :center }
      ),
      summary_table_header: wb_styles.add_style(
        bg_color: "1E293B",
        fg_color: "FFFFFF",
        b: true,
        sz: 9,
        alignment: { horizontal: :center, vertical: :center }
      ),
      cell: wb_styles.add_style(
        sz: 10,
        alignment: { vertical: :top, wrap_text: true }
      ),
      cell_phone: wb_styles.add_style(
        sz: 10,
        format_code: "@",
        alignment: { horizontal: :left, vertical: :top }
      ),
      cell_center: wb_styles.add_style(
        sz: 10,
        alignment: { horizontal: :center, vertical: :top }
      ),
      cell_currency: wb_styles.add_style(
        sz: 10,
        format_code: "#,##0.00",
        alignment: { horizontal: :right, vertical: :top }
      ),
      status_confirmed: wb_styles.add_style(
        bg_color: "DCFCE7",
        fg_color: "166534",
        b: true,
        sz: 10,
        alignment: { horizontal: :center, vertical: :top }
      ),
      status_pending: wb_styles.add_style(
        bg_color: "FEF3C7",
        fg_color: "92400E",
        b: true,
        sz: 10,
        alignment: { horizontal: :center, vertical: :top }
      ),
      status_cancelled: wb_styles.add_style(
        bg_color: "FEE2E2",
        fg_color: "991B1B",
        b: true,
        sz: 10,
        alignment: { horizontal: :center, vertical: :top }
      ),
      matrix_filled: wb_styles.add_style(
        bg_color: "F0FDF4",
        fg_color: "166534",
        b: true,
        sz: 9,
        alignment: { horizontal: :center, vertical: :center, wrap_text: true }
      ),
      matrix_empty: wb_styles.add_style(
        fg_color: "94A3B8",
        sz: 11,
        alignment: { horizontal: :center, vertical: :center }
      )
    }
  end
end
