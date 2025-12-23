class BusinessMatchingReportService
  def initialize(bookings, event_title = "Business Matching Report")
    @bookings = bookings
    @event_title = event_title
  end

  def generate_xlsx
    Rails.logger.info "DEBUG REPORT: Bookings count: #{@bookings.count}"
    Rails.logger.info "DEBUG REPORT: First 5 bookings: #{@bookings.first(5).inspect}"

    p = Axlsx::Package.new
    wb = p.workbook

    grouped_bookings = @bookings.group_by { |b| b[:event_title] || "General" }

    Rails.logger.info "DEBUG REPORT: Grouped bookings keys: #{grouped_bookings.keys.inspect}"

    grouped_bookings.each_with_index do |(group_title, bookings), index|
      next if bookings.empty?

      # Sheet name limited to 31 chars
      sheet_name = group_title.to_s.gsub(/[^0-9a-zA-Z \-_]/, '').truncate(31)
      sheet_name = "Sheet#{index + 1}" if sheet_name.blank?
      
      wb.add_worksheet(name: sheet_name) do |sheet|
        sheet.add_row headers
        
        sorted_bookings = sort_bookings(bookings)
        
        sorted_bookings.each do |booking|
          sheet.add_row row_data(booking)
        end
      end
    end

    xlsx_data = p.to_stream.read
    Rails.logger.info "DEBUG REPORT: Generated XLSX data length: #{xlsx_data.length} bytes"
    xlsx_data
  end

  private

  def sort_bookings(bookings)
    bookings.sort_by do |b|
      # 1. Sort by Comment Presence (inverse because false comes before true)
      has_comment = b[:host_comment].present? || b[:attendance].present? ? 0 : 1
      
      # 2. Sort by Deal Value (High to Low)
      deal_value = -1 * (b[:potential_deal_value].to_f rescue 0.0)

      # 3. Sort by Status (Absent/Cancelled last)
      # Assuming 'absent' or 'cancelled' status strings. 
      # We want 'confirmed' or others first.
      is_absent = ['absent', 'cancelled'].include?(b[:status].to_s.downcase) ? 1 : 0

      [is_absent, has_comment, deal_value]
    end
  end

  def headers
    ["Name", "Email", "Phone", "Date & Time", "Status", "Attendance", "Comment", "Potential Deal Value"]
  end

  def row_data(booking)
    [
      booking[:name],
      booking[:email],
      booking[:phone],
      "#{booking[:booking_date]} #{booking[:booking_time]}",
      booking[:status],
      booking[:attendance],
      booking[:host_comment],
      booking[:potential_deal_value]
    ]
  end
end
