require 'caxlsx'

module Rfid
  # The staff-facing RFID report as one Excel workbook, written for a client to
  # read rather than a developer to parse: plain words, durations as h:mm,
  # status chips instead of codes, and no sticker keys except on the Stickers
  # sheet. Built from the same Report and Attendance reads the panel uses, so
  # its figures always match the dashboard.
  class ReportWorkbook
    ANOMALY_LABELS = {
      'repeated_entry' => 'Scanned in again without leaving', 'unmatched_exit' => 'Exit scanned with no entry on record',
      'manual_exit' => 'Closed by staff', 'manual_entry' => 'Added by staff',
      'role_mismatch' => 'Scanned at the wrong kind of gate',
      'payload_binding_mismatch' => 'Sticker data did not match the ticket',
      'entered_without_check_in' => 'Entered without checking in at the desk'
    }.freeze

    STATIC_SHEETS = ['Summary', 'E-Certificate', 'No Gate Read', 'Guest Visits', 'Traffic'].freeze

    ID_WIDTH = 38 # tickets are UUIDs

    ELIGIBILITY_LABELS = {
      'qualified' => ['Qualified', :good], 'needs_feedback' => ['Needs feedback form', :warn],
      'in_progress' => ['In progress', :info], 'not_qualified' => ['Not qualified', :bad]
    }.freeze

    # `fields` are custom-field keys (e.g. the registration form's agency) to
    # show as extra columns after "Ticket type". Unknown keys are ignored.
    def initialize(event, now: Time.current, fields: [])
      @event = event
      @now = now
      @labels = self.class.custom_fields(event)
      @fields = Array(fields).map(&:to_s).uniq & @labels.keys
      @report = Report.new(event)
      @attendance = Attendance.new(event, now: now)
    end

    # { key => label } of the custom fields the event actually uses: its
    # labels_data plus keys found on tickets (registration forms add some,
    # labelled from the key), minus server-reserved "_" ones. This is what the
    # panel offers as optional report columns.
    def self.custom_fields(event)
      ticket_keys = event.tickets.where.not(custom_fields_data: {})
                         .distinct.pluck(Arel.sql('jsonb_object_keys(custom_fields_data)'))
      labels = event.labels_data.to_h
      (labels.keys + ticket_keys).uniq.reject { |key| key.to_s.start_with?('_') }
                                 .to_h { |key| [key, labels[key].presence || key.humanize] }
    end

    # The .xlsx file contents.
    def call
      package = Axlsx::Package.new(author: 'EventzFlow')
      @kit = SheetKit.new(package)
      STATIC_SHEETS.each { |name| @kit.claim_name(name) }
      sessions = @event.rfid_sessions.order(:starts_at, :id).to_a
      sheet_names = sessions.to_h { |session| [session.id, @kit.claim_name(session.name)] }
      SummarySheet.new(@kit, event: @event, now: @now, summary: @report.summary, sessions: @attendance.sessions,
                             types: type_rows, sheet_names: sheet_names).build
      sessions.each { |session| session_sheet(session, sheet_names[session.id]) }
      certificate_sheet
      no_gate_read_sheet
      guest_visits_sheet
      traffic_sheet
      package.to_stream.read
    end

    private

    def col(title, width, kind = :text)
      SheetKit::Column.new(title, width, kind)
    end

    def custom_cols
      @fields.map { |key| col(@labels[key], 30) }
    end

    # Cells for one ticket, in the order of `custom_cols`.
    def custom_cells(ticket_id)
      @custom_data ||= @event.tickets.pluck(:id, :custom_fields_data).to_h
      data = @custom_data[ticket_id].to_h
      @fields.map { |key| data[key].to_s.strip.presence }
    end

    def time(iso)
      iso && Time.zone.parse(iso)
    end

    def duration(seconds)
      seconds && seconds / 86_400.0
    end

    def type_rows
      @event.ticket_types.order(:name).map do |type|
        figures = @report.summary(ticket_type_id: type.id)
        [type.name, figures[:registered], figures[:checked_in], figures[:gate_scanned], figures[:inside],
         figures[:missed_scans].values.sum]
      end
    end

    # One sheet per session: everyone in the hall during it, then every
    # registered guest who was not.
    def session_sheet(session, name)
      window = "#{session.starts_at.strftime('%d %b %Y, %H:%M')} – #{session.ends_at.strftime('%H:%M')}"
      attendees, counts = @attendance.session_attendees(session)
      absent = absent_rows(session, attendees.to_set { |row| row[:id] })
      rows = attendees.map do |row|
        [row[:ticket_name], row[:ticket_type], *custom_cells(row[:id]), time(row[:first_in]), time(row[:last_out]), duration(row[:seconds]),
         [row[:seconds].to_f / session.duration_seconds, 1].min,
         row[:attended] ? ['Attended', :good] : ['Not enough time', :warn], attendee_note(row), row[:ticket_public_id]]
      end
      @kit.table(name, title: session.name,
                 subtitle: "#{window}  •  #{counts[:attended]} attended, #{counts[:partial]} not enough time, " \
                           "#{absent.length} not in the hall. Attended = in the hall for at least " \
                           "#{@event.rfid_attendance_percent}% of the session " \
                           "(#{format_hm(session.duration_seconds * @event.rfid_attendance_percent / 100)}).",
                 columns: [col('Guest', 28), col('Ticket type', 18), *custom_cols, col('First in', 20, :time), col('Last out', 20, :time),
                           col('Time in session (h:mm)', 16, :duration), col('Share of session', 12, :pct),
                           col('Result', 18), col('Note', 34), col('Ticket ID', ID_WIDTH)],
                 rows: rows + absent, tab: 'FF16A34A', empty: 'No guests registered.')
    end

    def absent_rows(session, present_ids)
      ended = session.ends_at <= @now
      @event.tickets.active.paid.includes(:ticket_type).order(:attendee_name, :id).reject { |t| present_ids.include?(t.id) }.map do |ticket|
        note = ticket.checked_in ? 'Checked in at the desk, never in the hall' : 'Did not check in'
        [ticket.attendee_name, ticket.ticket_type&.name, *custom_cells(ticket.id), nil, nil, 0.0, 0.0,
         ended ? ['Did not attend', :bad] : ['Not in the hall', :info], note, ticket.public_id]
      end
    end

    def format_hm(seconds)
      format('%d:%02d', seconds / 3600, seconds % 3600 / 60)
    end

    def attendee_note(row)
      notes = []
      notes << 'Still inside' if row[:still_inside]
      notes << "Came back #{row[:visit_count] - 1}x" if row[:visit_count] > 1
      notes.join(', ')
    end

    def certificate_sheet
      return if @attendance.eligibility_rows.empty?

      required = @event.rfid_sessions.where(mandatory: true).order(:starts_at, :id).to_a
      rows = @attendance.eligibility_rows.map do |row|
        by_session = row[:sessions].index_by { |item| item[:session_id] }
        [row[:ticket_name], row[:ticket_type], *custom_cells(row[:id]),
         *required.map { |s| by_session[s.id][:percent] / 100.0 },
         row[:feedback_submitted] ? ['Yes', :good] : ['No', :warn],
         ELIGIBILITY_LABELS.fetch(row[:status]), row[:override] ? "Allowed by staff: #{row[:override][:reason]}" : '', row[:ticket_public_id]]
      end
      @kit.table('E-Certificate', title: 'E-certificate eligibility',
                 subtitle: "Needs #{@event.rfid_attendance_percent}% of every required session, plus the feedback form.",
                 columns: [col('Guest', 28), col('Ticket type', 18), *custom_cols,
                           *required.map { |s| col(s.name.truncate(24), 16, :pct) },
                           col('Feedback form', 14), col('Status', 22), col('Staff note', 34), col('Ticket ID', ID_WIDTH)],
                 rows: rows, tab: 'FF7C3AED')
    end

    # Guests the desk checked in whom no gate has read, sticker-linked first:
    # those are the ones worth checking against the gate hardware.
    def no_gate_read_sheet
      tickets = @report.missed_scans_scope.to_a
      linked = @event.rfid_bindings.active.where(ticket_id: tickets.map(&:id)).pluck(:ticket_id, :captured_at).to_h
      rows = tickets.sort_by { |t| [linked.key?(t.id) ? 0 : 1, -t.check_in_at.to_i] }.map do |ticket|
        has_sticker = linked.key?(ticket.id)
        [ticket.attendee_name, ticket.ticket_type&.name, *custom_cells(ticket.id), ticket.check_in_at,
         has_sticker ? ['Sticker linked, no gate read', :warn] : ['No sticker linked', :bad], linked[ticket.id],
         has_sticker ? 'Has not entered yet, or the gate missed the sticker.' : 'Link a sticker at the desk so gates can read them.', ticket.public_id]
      end
      @kit.table('No Gate Read', title: 'Checked in at the desk, never read by a gate',
                 subtitle: "#{rows.length} guests. Sticker-linked guests are listed first.",
                 columns: [col('Guest', 28), col('Ticket type', 18), *custom_cols, col('Checked in at', 20, :time), col('Sticker', 28),
                           col('Sticker linked at', 20, :time), col('What it means', 44), col('Ticket ID', ID_WIDTH)],
                 rows: rows, tab: 'FFF59E0B', empty: 'Every checked-in guest has been read by a gate.')
    end

    def guest_visits_sheet
      groups, = @report.guest_visits(per_page: 10**9, now: @now)
      rows = groups.sort_by { |g| g[:ticket_name].to_s }.map do |group|
        [group[:ticket_name], group[:ticket_type], *custom_cells(group[:ticket_id]), group[:visit_count],
         time(group[:first_in]), time(group[:last_out]), duration(group[:total_seconds]),
         group[:status] == 'inside' ? ['Inside', :good] : ['Left', :info], notes_for(group[:anomalies]), group[:ticket_public_id]]
      end
      @kit.table('Guest Visits', title: 'Time in the hall, per guest',
                 subtitle: 'One row per guest, all their entries and exits added together.',
                 columns: [col('Guest', 28), col('Ticket type', 18), *custom_cols,
                           col('Times entered', 10, :int), col('First in', 20, :time), col('Last out', 20, :time),
                           col('Total time (h:mm)', 14, :duration), col('Now', 12), col('Note', 36), col('Ticket ID', ID_WIDTH)],
                 rows: rows, tab: 'FF0EA5E9', empty: 'No gate visits yet.')
    end

    def notes_for(codes)
      Array(codes).map { |code| ANOMALY_LABELS.fetch(code) { code.to_s.humanize } }.join('; ')
    end

    def traffic_sheet
      rows = @report.flow[:buckets].map { |b| [time(b[:at]), b[:entries], b[:exits], b[:inside]] }
      sheet, first, last = @kit.table('Traffic', title: 'Arrivals and departures over time',
                                      subtitle: 'How many guests came in, left, and were inside, per time slot.',
                                      columns: [col('Time slot', 20, :time), col('Came in', 12, :int),
                                                col('Left', 12, :int), col('Inside', 12, :int)],
                                      rows: rows, tab: 'FF0EA5E9', empty: 'No gate activity yet.')
      return if rows.empty?

      sheet.add_chart(Axlsx::LineChart, start_at: 'F4', end_at: 'O22', title: 'Guests inside the hall') do |chart|
        chart.add_series data: sheet["D#{first}:D#{last}"], labels: sheet["A#{first}:A#{last}"], title: 'Inside',
                         color: SheetKit::BLUE.delete_prefix('FF')
        chart.show_legend = false
      end
    end
  end
end
