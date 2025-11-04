require 'caxlsx'
require 'roo'

class TicketExcelService
  # Export tickets to Excel file
  # @param event_id [Integer] The event ID to export tickets for
  # @return [Hash] { file_path: String, export_log: ExportLog }
  def self.export(event_id)
    event = Event.find(event_id)
    tickets = event.tickets.includes(:ticket_type, :event)

    # Create exports directory if it doesn't exist
    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)

    # Generate filename with timestamp
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "tickets-#{event_id}-#{timestamp}.xlsx"
    file_path = exports_dir.join(filename)

    # Get label keys from event.labels_data (these will become columns)
    label_keys = event.labels_data&.keys || []

    # Create Excel workbook
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Tickets") do |sheet|
      # Build header row: fixed columns + dynamic label columns
      header_row = [
        'Attendee Name',
        'Attendee Email',
        'Attendee Phone',
        'Event Title',
        'Ticket Type',
        'Public ID',
        'QR Code',
        'Payment Status',
        'Checked In'
      ]
      # Add label columns (using the display names from event.labels_data values)
      label_keys.each do |key|
        header_row << event.labels_data[key] # Use the value as column header (e.g., "Role", "Company")
      end
      sheet.add_row header_row

      # Add data rows
      tickets.each do |ticket|
        row_data = [
          ticket.attendee_name,
          ticket.attendee_email,
          ticket.attendee_phone,
          event.title,
          ticket.ticket_type&.name,
          ticket.public_id,
          '', # QR Code column - will be filled with formula below
          ticket.payment_status,
          ticket.checked_in
        ]

        # Add values from ticket.custom_fields_data for each label key
        label_keys.each do |key|
          row_data << (ticket.custom_fields_data[key] || '')
        end

        sheet.add_row row_data
      end

      # Add QR code formula for each ticket row (starting from row 2)
      tickets.each_with_index do |ticket, index|
        row_number = index + 2 # +2 because Excel is 1-indexed and row 1 is headers
        # Formula: =IMAGE("https://quickchart.io/qr?text=" & ENCODEURL(F2))
        # F column is now the public_id column (6th column)
        cell = sheet.rows[index + 1].cells[6] # 0-indexed, so index+1 for data rows, column 7 for QR
        cell.value = "=IMAGE(\"https://quickchart.io/qr?text=\" & ENCODEURL(F#{row_number}))"
      end
    end

    # Save the file
    package.serialize(file_path.to_s)

    # Create export log
    export_log = ExportLog.create!(
      event_id: event_id,
      type: 'ticket-list',
      sheet_path: file_path.to_s
    )

    {
      file_path: file_path.to_s,
      export_log: export_log
    }
  end

  # Import tickets from Excel file
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded Excel file
  # @param dry_run [Boolean] If true, do not persist changes; return a report only
  # @param full [Boolean] If true, include full record data (all extracted fields + model + id) in response
  # @return [Hash] { created: {count: Integer, data: Array}, updated: {count: Integer, data: Array}, skipped: {count: Integer, data: Array}, duplicates_in_file: {count: Integer, data: Array}, errors: {count: Integer, data: Array} }
  def self.import(file, dry_run: false, full: false)
    results = {
      created: { count: 0, data: [] },
      skipped: { count: 0, data: [] },
      updated: { count: 0, data: [] },
      duplicates_in_file: { count: 0, data: [] },
      errors: { count: 0, data: [] }
    }

    begin
      # Open the Excel file
      xlsx = Roo::Spreadsheet.open(file.path)
      sheet = xlsx.sheet(0) # First sheet

      # Read header row to identify label columns
      header_row = []
      (1..sheet.last_column).each do |col|
        header_row << sheet.cell(1, col)&.to_s&.strip
      end

      # Fixed column positions
      fixed_columns = {
        attendee_name: 1,
        attendee_email: 2,
        attendee_phone: 3,
        event_title: 4,
        ticket_type: 5,
        public_id: 6,
        qr_code: 7,
        payment_status: 8,
        checked_in: 9
      }

      # Identify label columns (all columns after checked_in)
      label_columns = {}
      if sheet.last_column > 9
        (10..sheet.last_column).each do |col_idx|
          label_display_name = header_row[col_idx - 1] # -1 for 0-indexed array
          label_columns[col_idx] = label_display_name
        end
      end

      # Build event labels_data schema from header (map display names to keys)
      # We'll use lowercase, underscored version as key
      labels_schema = {}
      label_columns.each do |col_idx, display_name|
        # Convert display name to key (e.g., "Role" -> "role", "Coupon/Referral" -> "coupon/referral")
        key = display_name.downcase.strip
        labels_schema[key] = display_name
      end

      # First pass: collect candidates and collapse only when names match within same event+type
      candidates = {} # key => { attrs:, row_num: }
      (2..sheet.last_row).each do |row_num|
        begin
          attendee_name_raw = sheet.cell(row_num, fixed_columns[:attendee_name])
          attendee_email_raw = sheet.cell(row_num, fixed_columns[:attendee_email])
          attendee_phone_raw = sheet.cell(row_num, fixed_columns[:attendee_phone])
          event_title_raw = sheet.cell(row_num, fixed_columns[:event_title])
          ticket_type_raw = sheet.cell(row_num, fixed_columns[:ticket_type])
          payment_status_str = sheet.cell(row_num, fixed_columns[:payment_status])&.to_s&.strip
          checked_in_value = sheet.cell(row_num, fixed_columns[:checked_in])

          attendee_name = titleize_name(attendee_name_raw)
          attendee_email = normalize_email(attendee_email_raw)
          attendee_phone = normalize_phone(attendee_phone_raw)
          event_title = event_title_raw.to_s.strip
          effective_ticket_type_name = (ticket_type_raw.to_s.strip.presence || 'General Admission')

          # Read custom field values from label columns
          custom_fields_data = {}
          label_columns.each do |col_idx, display_name|
            value = sheet.cell(row_num, col_idx)&.to_s&.strip
            key = display_name.downcase.strip
            custom_fields_data[key] = value if value.present?
          end

          # Skip empty rows
          if empty_row?({
            attendee_name: attendee_name,
            attendee_email: attendee_email,
            attendee_phone: attendee_phone,
            event_title: event_title,
            ticket_type: effective_ticket_type_name,
            payment_status: payment_status_str,
            checked_in: checked_in_value
          }) && custom_fields_data.blank?
            results[:skipped][:count] += 1
            if full
              results[:skipped][:data] << {
                model: 'Ticket',
                id: nil,
                attendee_name: attendee_name,
                attendee_email: attendee_email,
                attendee_phone: attendee_phone,
                event_title: event_title,
                ticket_type: effective_ticket_type_name,
                payment_status: payment_status_str,
                checked_in: checked_in_value,
                **custom_fields_data
              }
            end
            next
          end

          # Minimal required: name and event
          if attendee_name.blank? || event_title.blank?
            results[:skipped][:count] += 1
            if full
              results[:skipped][:data] << {
                model: 'Ticket',
                id: nil,
                attendee_name: attendee_name,
                attendee_email: attendee_email,
                attendee_phone: attendee_phone,
                event_title: event_title,
                ticket_type: effective_ticket_type_name,
                payment_status: payment_status_str,
                checked_in: checked_in_value,
                **custom_fields_data
              }
            end
            next
          end

          key = [
            "evt:#{event_title.downcase.strip}",
            "type:#{effective_ticket_type_name.downcase.strip}",
            "name:#{normalize_name_key(attendee_name)}"
          ].join('|')

          attrs = {
            attendee_name: attendee_name,
            attendee_email: attendee_email,
            attendee_phone: attendee_phone,
            event_title: event_title,
            ticket_type: effective_ticket_type_name,
            payment_status: payment_status_str,
            checked_in: parse_boolean(checked_in_value),
            custom_fields_data: custom_fields_data
          }

          prev = candidates[key]
          if prev.nil? || row_completeness_score(attrs) > row_completeness_score(prev[:attrs])
            candidates[key] = { attrs: attrs, row_num: row_num }
          else
            results[:duplicates_in_file][:count] += 1
            if full
              results[:duplicates_in_file][:data] << {
                model: 'Ticket',
                id: nil,
                attendee_name: attendee_name,
                attendee_email: attendee_email,
                attendee_phone: attendee_phone,
                event_title: event_title,
                ticket_type: effective_ticket_type_name,
                payment_status: payment_status_str,
                checked_in: checked_in_value,
                **custom_fields_data
              }
            end
          end
        rescue StandardError => e
          error_message = "Row #{row_num}: #{e.message}"
          results[:errors][:count] += 1
          results[:errors][:data] << error_message
        end
      end

      # Second pass: apply to DB with update-if-more-complete policy
      candidates.each_value do |entry|
        attrs = entry[:attrs]
        attendee_name = attrs[:attendee_name]
        attendee_email = attrs[:attendee_email]
        attendee_phone = attrs[:attendee_phone]
        event_title = attrs[:event_title]
        ticket_type_name = attrs[:ticket_type]
        checked_in = attrs[:checked_in]
        payment_status_str = attrs[:payment_status]
        custom_fields_data = attrs[:custom_fields_data]

        normalized_payment_status = payment_status_str&.downcase&.gsub(/\s+|-/, '_')
        parsed_payment_status = case normalized_payment_status
                                when 'paid' then :paid
                                when 'failed' then :failed
                                when 'refunded_payment', 'refunded', 'refund', 'refundedpayment' then :refunded_payment
                                when 'pending', nil, '' then :pending
                                else :pending
                                end

        event = Event.find_or_create_by!(title: event_title) do |e|
          e.status = :draft
          e.start_date = 10.days.from_now
          e.end_date = 20.days.from_now
          e.visibility = true
          e.labels_data = labels_schema if labels_schema.present?
        end
        event.update(labels_data: labels_schema) if event.labels_data.blank? && labels_schema.present?

        ticket_type = event.ticket_types.find_or_create_by!(name: ticket_type_name) do |tt|
          tt.price = 0
          tt.quantity = 10000
          tt.status = :draft
        end

        # Find existing by name within same event+type
        existing = Ticket.find_by(event_id: event.id, ticket_type_id: ticket_type.id, attendee_name_norm: normalize_name_key(attendee_name))

        if existing
          # Update only if more complete
          existing_score = row_completeness_score(
            attendee_name: existing.attendee_name,
            attendee_email: existing.attendee_email,
            attendee_phone: existing.attendee_phone,
            ticket_type: existing.ticket_type&.name.to_s,
            payment_status: existing.payment_status.to_s,
            checked_in: existing.checked_in,
            custom_fields_data: existing.custom_fields_data || {}
          )
          new_score = row_completeness_score(attrs)
          if new_score > existing_score
            # Only upgrade payment status, never downgrade; never uncheck
            upgraded_payment_status = existing.payment_status
            if parsed_payment_status == :paid || (parsed_payment_status == :refunded_payment && existing.payment_status != 'paid') || parsed_payment_status == :failed
              # prioritize paid > refunded_payment > failed > pending
              statuses = { 'pending' => 0, 'failed' => 1, 'refunded_payment' => 2, 'paid' => 3 }
              if statuses[parsed_payment_status.to_s] > statuses[existing.payment_status.to_s]
                upgraded_payment_status = parsed_payment_status
              end
            end
            unless dry_run
              existing.update(
                attendee_name: attendee_name,
                attendee_phone: attendee_phone.presence || existing.attendee_phone,
                payment_status: upgraded_payment_status,
                checked_in: existing.checked_in || checked_in,
                custom_fields_data: existing.custom_fields_data.to_h.merge(custom_fields_data)
              )
            end
            results[:updated][:count] += 1
            if full
              record_data = {
                model: 'Ticket',
                id: existing.id.to_s,
                attendee_name: existing.attendee_name,
                attendee_email: existing.attendee_email,
                attendee_phone: existing.attendee_phone,
                event_title: event.title,
                ticket_type: ticket_type.name,
                payment_status: existing.payment_status.to_s,
                checked_in: existing.checked_in,
                **(existing.custom_fields_data || {})
              }
              results[:updated][:data] << record_data
            end
          end
          results[:skipped][:count] += 1
          if full && !(new_score > existing_score)
            record_data = {
              model: 'Ticket',
              id: existing.id.to_s,
              attendee_name: existing.attendee_name,
              attendee_email: existing.attendee_email,
              attendee_phone: existing.attendee_phone,
              event_title: event.title,
              ticket_type: ticket_type.name,
              payment_status: existing.payment_status.to_s,
              checked_in: existing.checked_in,
              **(existing.custom_fields_data || {})
            }
            results[:skipped][:data] << record_data
          end
          next
        end

        # If no name match, even if email/phone match, create a new ticket (per rules)
        ticket = nil
        unless dry_run
          ticket = Ticket.create!(
            event: event,
            ticket_type: ticket_type,
            attendee_name: attendee_name,
            attendee_email: attendee_email,
            attendee_phone: attendee_phone,
            checked_in: checked_in,
            status: :purchased,
            payment_status: parsed_payment_status,
            custom_fields_data: custom_fields_data
          )
        end
        results[:created][:count] += 1
        if full
          record_data = {
            model: 'Ticket',
            id: ticket ? ticket.id.to_s : nil,
            attendee_name: attendee_name,
            attendee_email: attendee_email,
            attendee_phone: attendee_phone,
            event_title: event_title,
            ticket_type: ticket_type_name,
            payment_status: parsed_payment_status.to_s,
            checked_in: checked_in,
            **custom_fields_data
          }
          results[:created][:data] << record_data
        end
      end

    rescue StandardError => e
      error_message = "File processing error: #{e.message}"
      results[:errors][:count] += 1
      results[:errors][:data] << error_message
    end

    results
  end

  private

  # Parse various boolean representations
  def self.parse_boolean(value)
    return false if value.nil? || value.to_s.strip.empty?

    case value.to_s.downcase.strip
    when 'true', '1', 'yes', 't', 'y'
      true
    when 'false', '0', 'no', 'f', 'n'
      false
    else
      false
    end
  end

  # Normalization helpers
  def self.normalize_email(value)
    key = value.to_s.strip.downcase
    key.present? ? key : nil
  end

  def self.normalize_phone(value)
    digits = value.to_s.gsub(/\D+/, '')
    digits.present? ? digits : nil
  end

  def self.titleize_name(value)
    s = value.to_s.strip
    return nil if s.empty?
    s.split(/\s+/).map { |w| w.downcase.capitalize }.join(' ')
  end

  def self.empty_row?(values_hash)
    values_hash.values.all? { |v| v.nil? || v.to_s.strip.empty? }
  end

  def self.normalize_name_key(value)
    key = value.to_s.strip.gsub(/\s+/, ' ').downcase
    key.present? ? key : nil
  end

  def self.row_completeness_score(attrs)
    core_keys = [:attendee_name, :attendee_email, :attendee_phone, :ticket_type, :payment_status, :checked_in]
    score = core_keys.count { |k| v = attrs[k]; !(v.nil? || v.to_s.strip.empty?) }
    score + (attrs[:custom_fields_data].is_a?(Hash) ? attrs[:custom_fields_data].values.count { |v| v.present? } : 0)
  end
end
