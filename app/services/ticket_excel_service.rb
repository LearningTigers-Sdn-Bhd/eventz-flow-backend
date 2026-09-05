require 'caxlsx'
require 'roo'

# Exports an event's tickets as an Excel workbook.
#
# Sheet 1 ("Tickets") is the reimportable source of truth: same column order
# TicketExcelService.import has always expected (Attendee Name .. Review
# Status, then labels) - only cell *styling* changed, never structure, so a
# round-trip export -> edit -> import keeps working unchanged. Every sheet
# after it (Entry Timeline, per ticket-type detail tabs, Summary) is a
# report-only view built for humans, never read back by #import.
class TicketExcelService
  BRAND_NAVY = 'FF1F2A44'
  BRAND_BLUE = 'FF2766EC'
  LIGHT_GRAY = 'FFF3F4F6'
  BORDER_GRAY = 'FFD1D5DB'
  TEXT_DARK = 'FF111827'
  TEXT_MUTED = 'FF6B7280'
  WHITE = 'FFFFFFFF'

  FLAT_HEADERS = [
    'Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title',
    'Ticket Type', 'Role', 'Public ID', 'QR Code', 'Payment Status',
    'Checked In', 'Created At', 'Review Status'
  ].freeze

  DETAIL_HEADERS = [
    'Attendee Name', 'Attendee Email', 'Attendee Phone', 'Role', 'Public ID',
    'Payment Status', 'Checked In', 'Check-in At', 'Check-in Location',
    'Checked In By', 'Created At', 'Review Status'
  ].freeze

  # Export tickets to Excel file
  # @param event_id [Integer] The event ID to export tickets for
  # @param ticket_type_id [Integer, nil] restrict to one ticket type; nil exports all types
  # @return [Hash] { file_path: String, export_log: ExportLog }
  def self.export(event_id, from: nil, to: nil, ticket_type_id: nil)
    new(event_id, from: from, to: to, ticket_type_id: ticket_type_id).export
  end

  def initialize(event_id, from:, to:, ticket_type_id:)
    @event = Event.find(event_id)
    @from = from
    @to = to
    @ticket_type_id = ticket_type_id
  end

  def export
    tickets = scoped_tickets.to_a
    label_keys, label_display = label_schema(tickets)

    package = Axlsx::Package.new(author: 'EventzFlow')
    define_styles(package)

    build_flat_sheet(package, tickets, label_keys, label_display)
    # Rescans only exist for events that allow them - showing the timeline
    # otherwise would just repeat the single check-in already on each ticket row.
    build_scan_history_sheet(package, tickets) if @event.multiple_scans?
    build_detail_sheets(package, tickets)
    build_summary_sheet(package, tickets)

    # Tickets must stay physical sheet 0 (#import blindly reads sheet(0)), but
    # Summary is what a human should see first - so open the file on it via
    # the workbook's "active tab" rather than reordering sheets.
    summary_index = package.workbook.worksheets.index { |ws| ws.name == 'Summary' }
    package.workbook.views << Axlsx::WorkbookView.new(active_tab: summary_index)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("tickets-#{@event.id}-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    export_log = ExportLog.create!(event_id: @event.id, type: 'ticket-list', sheet_path: file_path.to_s)

    { file_path: file_path.to_s, export_log: export_log }
  end

  private

  def scoped_tickets
    tickets = @event.tickets.includes(:ticket_type, :event, :ticket_application, :scanned_by)
    tickets = tickets.where('created_at >= ?', @from.beginning_of_day) if @from.present?
    tickets = tickets.where('created_at <= ?', @to.end_of_day) if @to.present?
    tickets = tickets.where(ticket_type_id: @ticket_type_id) if @ticket_type_id.present?
    tickets
  end

  # Label keys from event.labels_data (preferring sequential "Label N" keys),
  # plus any extra custom field keys injected directly into tickets that
  # aren't part of that schema (e.g. from registration forms).
  def label_schema(tickets)
    label_keys = self.class.preferred_label_keys(@event.labels_data)
    extra_keys = tickets.flat_map { |t| (t.custom_fields_data || {}).keys }
                        .uniq
                        .reject { |k| label_keys.include?(k) }
    all_keys = label_keys + extra_keys

    label_display = (@event.labels_data || {}).dup
    extra_keys.each do |key|
      label_display[key] = key.to_s.gsub('_', ' ').gsub(/\b\w/) { |c| c.upcase }
    end

    [all_keys, label_display]
  end

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

  def merge_row_across(sheet, column_count)
    row = sheet.rows.last
    sheet.merge_cells(row.cells[0..(column_count - 1)])
  end

  # Unique, Excel-legal (<=31 chars, no : \ / ? * [ ]) sheet name.
  def safe_sheet_name(name, used_names)
    base = name.to_s.strip.presence || 'Ticket Type'
    base = base.gsub(/[:\\\/\?\*\[\]]/, '-')[0, 31]

    candidate = base
    suffix = 2
    while used_names.include?(candidate)
      candidate = "#{base[0, 31 - suffix.to_s.length - 1]}-#{suffix}"
      suffix += 1
    end
    used_names << candidate
    candidate
  end

  # --- Sheet 1: Tickets (flat, reimportable - structure never changes) ---

  def build_flat_sheet(package, tickets, label_keys, label_display)
    package.workbook.add_worksheet(name: 'Tickets') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      headers = FLAT_HEADERS + label_keys.map { |key| label_display[key] }
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      sheet.column_widths(*([26, 30, 18, 22, 16, 12, 22, 10, 16, 12, 20, 16] + Array.new(label_keys.size, 20)))

      tickets.each_with_index do |ticket, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        text_style = index.even? ? @styles[:text] : @styles[:text_alt]
        date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]

        row_data = [
          ticket.attendee_name, ticket.attendee_email, ticket.attendee_phone, @event.title,
          ticket.ticket_type&.name, ticket.role, ticket.public_id, '',
          ticket.payment_status, ticket.checked_in,
          ticket.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          ticket.ticket_application&.review_status&.titleize || ''
        ]
        label_keys.each { |key| row_data << ((ticket.custom_fields_data || {})[key] || '') }

        row_styles = [style, style, text_style, style, style, style, text_style, style,
                      style, style, date_style, style] + Array.new(label_keys.size, style)
        sheet.add_row(row_data, style: row_styles)

        row_number = index + 2
        sheet.rows[index + 1].cells[7].value =
          "=IMAGE(\"https://quickchart.io/qr?text=\" & ENCODEURL(G#{row_number}))"
      end

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A2'
        pane.state = :frozen
        pane.y_split = 1
      end
      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
    end
  end

  # --- Per ticket-type detail tabs (report-only: check-in data, never reimported) ---

  def build_detail_sheets(package, tickets)
    used_names = ['Tickets']
    tickets.group_by { |t| t.ticket_type&.name || 'Unassigned' }.each do |type_name, type_tickets|
      package.workbook.add_worksheet(name: safe_sheet_name(type_name, used_names)) do |sheet|
        sheet.sheet_pr.tab_color = BRAND_BLUE
        sheet.add_row DETAIL_HEADERS, style: Array.new(DETAIL_HEADERS.size, @styles[:table_header]), height: 18
        sheet.column_widths 26, 30, 18, 14, 22, 16, 12, 20, 22, 22, 20, 16

        type_tickets.each_with_index do |ticket, index|
          style = index.even? ? @styles[:cell] : @styles[:cell_alt]
          text_style = index.even? ? @styles[:text] : @styles[:text_alt]
          date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]

          sheet.add_row(
            [
              ticket.attendee_name, ticket.attendee_email, ticket.attendee_phone, ticket.role,
              ticket.public_id, ticket.payment_status.to_s.titleize, ticket.checked_in ? 'Yes' : 'No',
              ticket.check_in_at, check_in_location_for(ticket), ticket.scanned_by&.full_name,
              ticket.created_at, ticket.ticket_application&.review_status&.titleize || ''
            ],
            style: [style, style, text_style, style, text_style, style, style,
                    date_style, style, style, date_style, style]
          )
        end

        sheet.sheet_view.pane { |pane| pane.top_left_cell = 'A2'; pane.state = :frozen; pane.y_split = 1 }
        sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      end
    end
  end

  def check_in_location_for(ticket)
    first_scan_locations[ticket.id]
  end

  # First scan's location per ticket, computed once for the whole export.
  def first_scan_locations
    @first_scan_locations ||= ScanLog.where(scannable_type: 'Ticket', event_id: @event.id)
                                      .includes(:event_location)
                                      .order(:scanned_at)
                                      .each_with_object({}) { |log, h| h[log.scannable_id] ||= log.event_location&.name }
  end

  # --- Summary ---

  def build_summary_sheet(package, tickets)
    package.workbook.add_worksheet(name: 'Summary') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.sheet_view.tab_selected = true
      sheet.column_widths 28, 22, 22, 22, 22, 22
      sheet.merge_cells('A1:F1')
      sheet.add_row [@event.title], style: @styles[:title], height: 28
      sheet.add_row ["Ticket Report  •  Generated #{Time.current.strftime('%d %b %Y, %I:%M %p')}"],
                    style: @styles[:subtitle]
      sheet.add_row []

      sheet.add_row ['Overview'], style: @styles[:section_header]
      merge_row_across(sheet, 6)

      checked_in_count = tickets.count(&:checked_in)
      paid_count = tickets.count { |t| t.payment_status == 'paid' }

      sheet.add_row ['Total Tickets', 'Checked In', 'Not Checked In', 'Paid', 'Pending/Other', 'Ticket Types'],
                    style: Array.new(6, @styles[:stat_label])
      sheet.add_row [
        tickets.size, checked_in_count, tickets.size - checked_in_count, paid_count,
        tickets.size - paid_count, tickets.map { |t| t.ticket_type&.name }.uniq.compact.size
      ], style: Array.new(6, @styles[:stat_value]), height: 20

      sheet.add_row []
      sheet.add_row ['By Ticket Type'], style: @styles[:section_header]
      merge_row_across(sheet, 6)
      tickets.group_by { |t| t.ticket_type&.name || 'Unassigned' }.each do |type_name, type_tickets|
        sheet.add_row [type_name, type_tickets.size, type_tickets.count(&:checked_in)],
                      style: [@styles[:cell], @styles[:cell], @styles[:cell]]
      end

      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
      sheet.print_options.set(horizontal_centered: true)
    end
  end

  # --- Entry Timeline (every scan event; only when include_rescans is true) ---

  def build_scan_history_sheet(package, tickets)
    ticket_ids = tickets.map(&:id)
    headers = ['Attendee Name', 'Ticket Type', 'Scanned At', 'Source', 'Location', 'Scanned By']
    source_labels = { 'staff_scan' => 'Staff scan', 'self_check_in' => 'Self check-in', 'kiosk' => 'Public Check-in Page' }

    logs = ScanLog.where(scannable_type: 'Ticket', scannable_id: ticket_ids)
                  .includes(:event_location, :scanned_by, scannable: :ticket_type)
                  .order(:scanned_at)

    package.workbook.add_worksheet(name: 'Entry Timeline') do |sheet|
      sheet.sheet_pr.tab_color = BRAND_BLUE
      sheet.add_row headers, style: Array.new(headers.size, @styles[:table_header]), height: 18
      sheet.column_widths 26, 18, 20, 20, 22, 22

      logs.each_with_index do |log, index|
        style = index.even? ? @styles[:cell] : @styles[:cell_alt]
        date_style = index.even? ? @styles[:date_cell] : @styles[:date_cell_alt]
        ticket = log.scannable

        sheet.add_row(
          [
            ticket&.attendee_name, ticket&.ticket_type&.name, log.scanned_at,
            source_labels[log.source] || log.source.to_s.titleize,
            log.event_location&.name, log.scanned_by&.full_name
          ],
          style: [style, style, date_style, style, style, style]
        )
      end

      sheet.sheet_view.pane { |pane| pane.top_left_cell = 'A2'; pane.state = :frozen; pane.y_split = 1 }
      sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
    end
  end

  # Import tickets from Excel file
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded Excel file
  # @param dry_run [Boolean] If true, do not persist changes; return a report only
  # @param full [Boolean] If true, include full record data (all extracted fields + model + id) in response
  # @param no_label [Boolean] If true, map custom fields to sequential "Label N" keys; if false, use header names as keys
  # @return [Hash] { created: {count: Integer, data: Array}, updated: {count: Integer, data: Array}, skipped: {count: Integer, data: Array}, duplicates_in_file: {count: Integer, data: Array}, errors: {count: Integer, data: Array} }
  def self.import(file, dry_run: false, full: false, no_label: false)
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
        role: 6,
        public_id: 7,
        qr_code: 8,
        payment_status: 9,
        checked_in: 10
      }

      # Detect if file has the new format with Created At at column 11
      has_created_at_column = header_row[10]&.strip == 'Created At'
      label_start_col = has_created_at_column ? 12 : 11

      # Identify label columns (all columns after fixed columns)
      label_columns = {}
      if sheet.last_column >= label_start_col
        (label_start_col..sheet.last_column).each do |col_idx|
          label_display_name = header_row[col_idx - 1] # -1 for 0-indexed array
          label_columns[col_idx] = label_display_name
        end
      end

      # Build event labels_data schema from header
      # If no_label is true: map to sequential "Label N" keys
      # If no_label is false: use machine keys derived from header display names
      labels_schema = {}
      label_columns.each_with_index do |(_col_idx, display_name), index|
        key = if no_label
          "Label #{index + 1}"
        else
          machine_key_for(display_name)
        end
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
          role_raw = sheet.cell(row_num, fixed_columns[:role])
          payment_status_str = sheet.cell(row_num, fixed_columns[:payment_status])&.to_s&.strip
          checked_in_value = sheet.cell(row_num, fixed_columns[:checked_in])

          attendee_name = titleize_name(attendee_name_raw)
          attendee_email = normalize_email(attendee_email_raw)
          attendee_phone = normalize_phone(attendee_phone_raw)
          event_title = event_title_raw.to_s.strip
          role = role_raw.to_s.strip
          effective_ticket_type_name = (ticket_type_raw.to_s.strip.presence || 'General Admission')

          # Read custom field values from label columns
          # Always include all label keys, even if empty, to match event's labels_data structure
          custom_fields_data = {}
          label_columns.each_with_index do |(col_idx, display_name), index|
            value = sheet.cell(row_num, col_idx)&.to_s&.strip
            # Use the same keying rule as labels_schema for this import run
            key = if no_label
              "Label #{index + 1}"
            else
              machine_key_for(display_name)
            end
            # Include key even if value is empty to maintain structure with event.labels_data
            custom_fields_data[key] = value.presence || ''
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
            role: role,
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

      # Update labels_data once per unique event before processing tickets
      # This ensures all tickets see the updated labels_data structure
      events_processed = {}
      candidates.each_value do |entry|
        event_title = entry[:attrs][:event_title]
        next if events_processed[event_title]

        event = Event.find_or_create_by!(title: event_title) do |e|
          e.status = :draft
          e.start_date = 10.days.from_now
          e.end_date = 20.days.from_now
          e.visibility = true
          e.labels_data = labels_schema if labels_schema.present?
        end
        # Reload to ensure we have the latest labels_data (especially if event was just created)
        event.reload
        # Normalize/replace labels_data schema according to selected mode for this import run
        if labels_schema.present?
          existing_labels = event.labels_data || {}
          existing_style = existing_labels.keys.any? { |k| k.to_s.match?(/^Label \d+$/) } ? :labelN : :header
          import_style = no_label ? :labelN : :header

          if existing_style != import_style
            # Replace entirely to ensure consistency with this import run's rule
            if event.labels_data != labels_schema
              event.update!(labels_data: labels_schema)
              event.reload
            end
          else
            # Same style: merge and update only if changed
            merged_labels = if import_style == :labelN
              merge_label_n_schema(existing_labels, labels_schema)
            else
              existing_labels.merge(labels_schema)
            end
            existing_array = (existing_labels || {}).to_a.sort_by { |k, _| k.to_s }
            merged_array = merged_labels.to_a.sort_by { |k, _| k.to_s }
            has_changes = existing_array != merged_array
            if has_changes
              event.update!(labels_data: merged_labels)
              event.reload
            end
          end

          # Ensure all existing tickets for this event are synchronized to the selected keying style
          # so that their custom_fields_data keys match event.labels_data (unless dry_run)
          synchronize_event_tickets(event, labels_schema, import_style, dry_run)
        end
        events_processed[event_title] = event
      end

      # Second pass: apply to DB with update-if-more-complete policy
      candidates.each_value do |entry|
        attrs = entry[:attrs]
        attendee_name = attrs[:attendee_name]
        attendee_email = attrs[:attendee_email]
        attendee_phone = attrs[:attendee_phone]
        event_title = attrs[:event_title]
        ticket_type_name = attrs[:ticket_type]
        role = attrs[:role]
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

        # Use the pre-processed event from events_processed
        event = events_processed[event_title]

        ticket_type = event.ticket_types.find_or_create_by!(name: ticket_type_name) do |tt|
          tt.price = 0
          tt.quantity = 10000
          tt.status = :draft
        end

        # Find existing by name within same event+type
        existing = Ticket.find_by(event_id: event.id, ticket_type_id: ticket_type.id, attendee_name_norm: normalize_name_key(attendee_name))

        if existing
          # Track changes before update
          changed_fields = []
          original_payment_status = existing.payment_status
          original_custom_fields = (existing.custom_fields_data || {}).deep_dup

          # Unconditional upgrade-to-paid rule: if incoming status is paid and existing is not,
          # upgrade payment_status to paid regardless of completeness. Never downgrade and respect dry_run.
          if parsed_payment_status == :paid && !existing.paid?
            # Payment status will change from existing to paid
            changed_fields << 'payment_status'

            unless dry_run
              # Ensure all preferred label keys from event.labels_data are present in custom_fields_data
              base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
              merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
              # Remove legacy keys not part of preferred label keys
              merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
              merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)

              # Check if custom_fields_data changed
              if merged_custom_fields != original_custom_fields
                changed_fields << 'custom_fields_data'
              end

              existing.update(
                payment_status: :paid,
                role: role.presence || existing.role,
                custom_fields_data: merged_custom_fields
              )
            else
              # In dry_run mode, check if custom_fields_data would change
              base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
              merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
              merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
              merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)
              if merged_custom_fields != original_custom_fields
                changed_fields << 'custom_fields_data'
              end
            end
            results[:updated][:count] += 1
            # Always include updated items with changed_fields, even when full: false
            record_data = {
              model: 'Ticket',
              id: existing.id.to_s,
              changed_fields: changed_fields
            }
            # Include full data if full: true
            if full
              record_data.merge!({
                attendee_name: existing.attendee_name,
                attendee_email: existing.attendee_email,
                attendee_phone: existing.attendee_phone,
                event_title: event.title,
                ticket_type: ticket_type.name,
                role: existing.role,
                payment_status: 'paid',
                checked_in: existing.checked_in,
                **(existing.custom_fields_data || {})
              })
            end
            results[:updated][:data] << record_data
            # Proceed to next candidate; we've applied the paid upgrade.
            next
          end

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
            # Track changes for this update path
            changed_fields = []

            # Only upgrade payment status, never downgrade; never uncheck
            upgraded_payment_status = existing.payment_status
            if parsed_payment_status == :paid || (parsed_payment_status == :refunded_payment && existing.payment_status != 'paid') || parsed_payment_status == :failed
              # prioritize paid > refunded_payment > failed > pending
              statuses = { 'pending' => 0, 'failed' => 1, 'refunded_payment' => 2, 'paid' => 3 }
              if statuses[parsed_payment_status.to_s] > statuses[existing.payment_status.to_s]
                upgraded_payment_status = parsed_payment_status
                changed_fields << 'payment_status' if original_payment_status != upgraded_payment_status
              end
            end
            unless dry_run
              # Ensure all preferred label keys from event.labels_data are present in custom_fields_data
              # Start with event labels (as base) to ensure new labels are included
              base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
              # Merge existing ticket data, then import data (preserving existing values)
              merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
              merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
              merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)

              # Check if custom_fields_data changed
              if merged_custom_fields != original_custom_fields
                changed_fields << 'custom_fields_data'
              end

              existing.update(
                attendee_name: attendee_name,
                attendee_phone: attendee_phone.presence || existing.attendee_phone,
                role: role.presence || existing.role,
                payment_status: upgraded_payment_status,
                checked_in: existing.checked_in || checked_in,
                custom_fields_data: merged_custom_fields
              )
            else
              # In dry_run mode, check if custom_fields_data would change
              base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
              merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
              merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
              merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)
              if merged_custom_fields != original_custom_fields
                changed_fields << 'custom_fields_data'
              end
            end
            results[:updated][:count] += 1
            # Always include updated items with changed_fields, even when full: false
            record_data = {
              model: 'Ticket',
              id: existing.id.to_s,
              changed_fields: changed_fields
            }
            # Include full data if full: true
            if full
              record_data.merge!({
                attendee_name: existing.attendee_name,
                attendee_email: existing.attendee_email,
                attendee_phone: existing.attendee_phone,
                event_title: event.title,
                ticket_type: ticket_type.name,
                role: existing.role,
                payment_status: existing.payment_status.to_s,
                checked_in: existing.checked_in,
                **(existing.custom_fields_data || {})
              })
            end
            results[:updated][:data] << record_data
            next
          end

          # Always update custom_fields_data even if row isn't more complete
          # This ensures custom field values are updated when they change
          # Track if any changes occurred to determine if we should mark as updated
          changed_fields_for_skip = []

          # Check if payment_status or role would change (even if row isn't more complete)
          # Only upgrade payment status, never downgrade
          upgraded_payment_status_for_skip = existing.payment_status
          if parsed_payment_status == :paid || (parsed_payment_status == :refunded_payment && existing.payment_status != 'paid') || parsed_payment_status == :failed
            # prioritize paid > refunded_payment > failed > pending
            statuses = { 'pending' => 0, 'failed' => 1, 'refunded_payment' => 2, 'paid' => 3 }
            if statuses[parsed_payment_status.to_s] > statuses[existing.payment_status.to_s]
              upgraded_payment_status_for_skip = parsed_payment_status
              if original_payment_status != upgraded_payment_status_for_skip
                changed_fields_for_skip << 'payment_status'
              end
            end
          end

          if role.present? && role != existing.role
            changed_fields_for_skip << 'role'
          end

          unless dry_run
            # Ensure all preferred label keys from event.labels_data are present in custom_fields_data
            base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
            # Merge existing ticket data, then import data (import data takes precedence for values)
            merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
            merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
            merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)

            # Check if custom_fields_data changed
            if merged_custom_fields != original_custom_fields
              changed_fields_for_skip << 'custom_fields_data'
            end

            # Only update if custom_fields_data actually changed
            if merged_custom_fields != (existing.custom_fields_data || {})
              existing.update(custom_fields_data: merged_custom_fields)
            end

            # Update payment_status if it changed
            if upgraded_payment_status_for_skip != existing.payment_status
              existing.update(payment_status: upgraded_payment_status_for_skip)
            end

            # Update role if it changed
            if role.present? && role != existing.role
              existing.update(role: role)
            end
          else
            # In dry_run mode, check if custom_fields_data would change
            base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
            merged_custom_fields = base_custom_fields.merge(existing.custom_fields_data.to_h).merge(custom_fields_data)
            merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
            merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)
            if merged_custom_fields != original_custom_fields
              changed_fields_for_skip << 'custom_fields_data'
            end
          end

          # If payment_status or custom_fields_data changed, mark as updated instead of skipped
          if changed_fields_for_skip.any?
            results[:updated][:count] += 1
            # Always include updated items with changed_fields, even when full: false
            # Reload to get updated values after update
            existing.reload if !dry_run
            record_data = {
              model: 'Ticket',
              id: existing.id.to_s,
              changed_fields: changed_fields_for_skip
            }
            # Include full data if full: true
            if full
              record_data.merge!({
                attendee_name: existing.attendee_name,
                attendee_email: existing.attendee_email,
                attendee_phone: existing.attendee_phone,
                event_title: event.title,
                ticket_type: ticket_type.name,
                role: existing.role,
                payment_status: existing.payment_status.to_s,
                checked_in: existing.checked_in,
                **(existing.custom_fields_data || {})
              })
            end
            results[:updated][:data] << record_data
          else
            # No changes, mark as skipped
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
          end
          next
        end

        # If no name match, even if email/phone match, create a new ticket (per rules)
        # Ensure response payload (and persisted data) always include the full label schema
        base_custom_fields = self.preferred_label_keys(event.labels_data).index_with { |_k| '' }
        merged_custom_fields = base_custom_fields.merge(custom_fields_data)
        merged_custom_fields = self.sanitize_custom_fields(merged_custom_fields, event.labels_data)
        merged_custom_fields = self.strip_empty_custom_fields(merged_custom_fields)

        ticket = nil
        unless dry_run
          ticket = Ticket.create!(
            event: event,
            ticket_type: ticket_type,
            attendee_name: attendee_name,
            attendee_email: attendee_email,
            attendee_phone: attendee_phone,
            role: role,
            checked_in: checked_in,
            status: :purchased,
            payment_status: parsed_payment_status,
            custom_fields_data: merged_custom_fields
          )
        end
        results[:created][:count] += 1
        record_data = {
          model: 'Ticket',
          id: ticket ? ticket.id.to_s : nil,
          attendee_name: attendee_name,
          attendee_email: attendee_email,
          attendee_phone: attendee_phone,
          event_title: event_title,
          ticket_type: ticket_type_name,
          role: role,
          payment_status: parsed_payment_status.to_s,
          checked_in: checked_in
        }.merge(merged_custom_fields)

        results[:created][:data] << record_data
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
    core_keys = [:attendee_name, :attendee_email, :attendee_phone, :ticket_type, :role, :payment_status, :checked_in]
    score = core_keys.count { |k| v = attrs[k]; !(v.nil? || v.to_s.strip.empty?) }
    score + (attrs[:custom_fields_data].is_a?(Hash) ? attrs[:custom_fields_data].values.count { |v| v.present? } : 0)
  end

  # Prefer sequential label keys ("Label N") when present; otherwise, return all keys as-is
  def self.preferred_label_keys(labels_data)
    keys = (labels_data || {}).keys
    label_keys = keys.select { |k| k.to_s.match?(/^Label \d+$/) }
    if label_keys.any?
      label_keys.sort_by { |k| k.to_s.match(/^Label (\d+)$/)[1].to_i }
    else
      keys
    end
  end

  # Remove any legacy custom field keys that are not part of preferred label keys
  def self.sanitize_custom_fields(custom_fields, labels_data)
    allowed_keys = self.preferred_label_keys(labels_data)
    return {} if allowed_keys.empty?
    custom_fields.slice(*allowed_keys)
  end

  # Remove keys whose values are nil/blank strings after trimming
  def self.strip_empty_custom_fields(custom_fields)
    # Preserve empty-string values for defined label keys; normalize nil to ""
    custom_fields.transform_values { |v| v.nil? ? '' : v.to_s }
  end

  # Convert a display name like "Dietary Restrictions" to a machine key "dietary_restrictions"
  def self.machine_key_for(display_name)
    s = display_name.to_s.downcase
    s = s.gsub(/[^a-z0-9]+/, '_')
    s = s.gsub(/_{2,}/, '_')
    s = s.gsub(/^_|_$/,'')
    s
  end

  # Merge label schemas for Label N style without overwriting existing mappings.
  # - existing_labels: { 'Label 1' => 'Role', 'Label 2' => 'Company' }
  # - labels_schema: { 'Label 1' => 'Role', 'Label 2' => 'Department' } (built from header order)
  # Result: { 'Label 1' => 'Role', 'Label 2' => 'Company', 'Label 3' => 'Department' }
  def self.merge_label_n_schema(existing_labels, labels_schema)
    merged = (existing_labels || {}).dup
    return merged if labels_schema.blank?

    # 1) Update existing Label N positions with incoming display names by index
    incoming_values_in_order = labels_schema.to_a.sort_by do |(k, _)|
      k.to_s.match?(/^Label \d+$/) ? k.to_s.match(/^Label (\d+)$/)[1].to_i : 0
    end.map { |(_k, v)| v }

    incoming_values_in_order.each_with_index do |display_name, idx|
      label_key = "Label #{idx + 1}"
      if merged.key?(label_key)
        # Update only when names are semantically similar (avoid overwriting unrelated labels)
        existing_val = merged[label_key].to_s.downcase
        incoming_val = display_name.to_s.downcase
        if existing_val.include?(incoming_val) || incoming_val.include?(existing_val)
          merged[label_key] = display_name
        end
      end
    end

    # 2) Append any new display names that are not already present
    existing_values = merged.values
    next_index = merged.keys
      .select { |k| k.to_s.match?(/^Label \d+$/) }
      .map { |k| k.to_s.match(/^Label (\d+)$/)[1].to_i }
      .max.to_i

    incoming_values_in_order.each do |display_name|
      next if existing_values.include?(display_name)
      next_index += 1
      merged["Label #{next_index}"] = display_name
      existing_values << display_name
    end

    merged
  end

  # Synchronize all tickets of an event so their custom_fields_data keys match the current labels schema style
  # import_style: :labelN or :header
  def self.synchronize_event_tickets(event, labels_schema, import_style, dry_run)
    return if dry_run

    # Build preferred base keys from current event.labels_data
    target_keys = self.preferred_label_keys(event.labels_data)
    base = target_keys.index_with { |_k| '' }

    # Precompute mapping for alternate keys to help migrate values across styles
    # labels_schema is key (current style) => display name
    mapping = labels_schema.to_a.sort_by do |(k, _)|
      if k.to_s.match?(/^Label \d+$/)
        k.to_s.match(/^Label (\d+)$/)[1].to_i
      else
        # For header style, preserve order by display name occurrence (approximate by array order)
        # sort_by returns 0 for all non Label keys to keep given order
        0
      end
    end

    event.tickets.find_each do |ticket|
      original = ticket.custom_fields_data.to_h
      # Start with base keys (ensures presence of all keys)
      new_fields = base.dup

      mapping.each_with_index do |(current_key, display_name), index|
        target_key = if import_style == :labelN
          "Label #{index + 1}"
        else
          machine_key_for(display_name)
        end
        alt_key = if import_style == :labelN
          # alternate is machine key
          machine_key_for(display_name)
        else
          # alternate is Label N
          "Label #{index + 1}"
        end

        value = original[target_key]
        value = original[alt_key] if (value.nil? || value.to_s.strip.empty?)
        new_fields[target_key] = value.to_s
      end

      new_fields = self.sanitize_custom_fields(new_fields, event.labels_data)
      new_fields = self.strip_empty_custom_fields(new_fields)

      if new_fields != original
        ticket.update_columns(custom_fields_data: new_fields) # skip callbacks for speed; safe due to JSONB
      end
    end
  end
end
