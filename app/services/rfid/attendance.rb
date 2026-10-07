module Rfid
  # Session attendance and e-certificate eligibility, derived from the gate
  # visits. Nothing is scanned per session: a guest's time in a session is how
  # long their visits overlap its window (an open visit counts up to `now`,
  # never past the session end).
  #
  # A guest "attended" a session when that overlap is at least
  # `event.rfid_attendance_percent` of the session's length. They qualify for
  # the e-certificate when they attended every *mandatory* session and have
  # submitted the event's feedback form. Staff can waive the attendance rule for
  # one guest (`Rfid::Correction` cert_override); feedback is still required.
  class Attendance
    STATUSES = %w[qualified needs_feedback in_progress not_qualified].freeze

    def self.qualified_ticket_ids(event)
      new(event).eligibility_rows.select { |row| row[:status] == 'qualified' }.map { |row| row[:id] }
    end

    # Guests who met every mandatory session (or were waived by staff),
    # whether or not they answered the feedback form.
    def self.sessions_done_ticket_ids(event)
      new(event).eligibility_rows.select { |row| row[:sessions_met] }.map { |row| row[:id] }
    end

    def initialize(event, now: Time.current)
      @event = event
      @now = now
    end

    def sessions
      all_sessions.map { |session| session_row(session) }
    end

    # One row per guest who was inside during the session. Their visits are
    # clipped to the window and added up, so leaving and coming back (toilet,
    # phone call) is still one row with less time, never several rows.
    def session_attendees(session, status: nil, query: nil, ticket_type_id: nil)
      by_id = tickets.index_by(&:id)
      need = need_seconds(session)
      rows = session_visits(session).group_by(&:ticket_id).filter_map do |ticket_id, visits|
        ticket = by_id[ticket_id]
        next if ticket.nil?

        attendee_row(ticket, visits, session, need)
      end
      rows = filter_rows(rows, query: query, ticket_type_id: ticket_type_id)
      counts = { attended: rows.count { |row| row[:attended] }, partial: rows.count { |row| !row[:attended] } }
      rows = rows.select { |row| row[:attended] == (status == 'attended') } if %w[attended partial].include?(status)
      [rows.sort_by { |row| [-row[:seconds], row[:ticket_name].to_s] }, counts]
    end

    # Search (name, ticket id, email, phone) and ticket-type narrowing shared by
    # the attendee and e-certificate lists.
    def filter_rows(rows, query: nil, ticket_type_id: nil, custom_fields: nil)
      by_id = tickets.index_by(&:id)
      custom_fields&.each do |key, value|
        rows = rows.select { |row| by_id[row[:id]]&.custom_fields_data.to_h[key].to_s.strip == value.to_s.strip }
      end
      rows = rows.select { |row| row[:ticket_type_id].to_s == ticket_type_id.to_s } if ticket_type_id.present?
      rows = rows.select { |row| matches_query?(row, by_id[row[:id]], query) } if query.present?
      rows
    end

    # Registration-form answers staff can narrow a bulk action by, e.g. category
    # or agency name: { key:, values: [...] } for every custom field. Free-text
    # fields with thousands of distinct answers (names, IC numbers) are left out.
    CUSTOM_FIELD_MAX_VALUES = 2000

    def custom_field_options
      excluded = Ticket::RESERVED_CUSTOM_FIELD_KEYS + Ticket::DOCUMENT_KEYS
      values = Hash.new { |hash, key| hash[key] = Set.new }
      tickets.each do |ticket|
        ticket.custom_fields_data.to_h.each do |key, value|
          next if excluded.include?(key) || !value.is_a?(String) || value.strip.empty?

          values[key] << value.strip
        end
      end
      values.filter_map do |key, set|
        { key: key, values: set.to_a.sort } if set.size <= CUSTOM_FIELD_MAX_VALUES
      end.sort_by { |field| field[:key] }
    end

    def ticket_types
      event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } }
    end

    # True when this one guest should get the e-certificate automatically after
    # submitting feedback. Events without mandatory sessions have no attendance
    # rule, so feedback alone is enough there.
    def qualified?(ticket)
      required = required_sessions
      return true if required.empty?

      row = eligibility_row(ticket, required, Set[ticket.id], cert_overrides[ticket.id])
      row[:status] == 'qualified'
    end

    def eligibility_summary
      rows = eligibility_rows
      STATUSES.to_h { |status| [status.to_sym, rows.count { |row| row[:status] == status }] }
              .merge(required_sessions: required_sessions.length)
    end

    def eligibility_rows
      @eligibility_rows ||= begin
        required = required_sessions
        return [] if required.empty?

        feedback_ids = feedback_ticket_ids
        overrides = cert_overrides
        tickets.map { |ticket| eligibility_row(ticket, required, feedback_ids, overrides[ticket.id]) }
      end
    end

    private

    attr_reader :event, :now

    def all_sessions
      @all_sessions ||= event.rfid_sessions.order(:starts_at, :id).to_a
    end

    def required_sessions
      all_sessions.select(&:mandatory)
    end

    def tickets
      @tickets ||= event.tickets.active.paid.includes(:ticket_type).order(:attendee_name, :id).to_a
    end

    def feedback_ticket_ids
      FeedbackResponse.joins(:feedback_form).where(feedback_forms: { event_id: event.id })
                      .where.not(ticket_id: nil).pluck(:ticket_id).to_set
    end

    # { ticket_id => the granting correction } — the latest correction per guest
    # decides, so a revoke undoes a grant without losing either record.
    def cert_overrides
      event.rfid_corrections.where(kind: %w[cert_override cert_override_revoked]).order(:id)
           .each_with_object({}) { |c, by_ticket| by_ticket[c.ticket_id] = c }
           .select { |_, c| c.kind == 'cert_override' }
    end

    def need_seconds(session)
      (session.duration_seconds * event.rfid_attendance_percent / 100.0).ceil
    end

    # { ticket_id => seconds inside during the session }
    def seconds_for(session)
      @seconds ||= {}
      @seconds[session.id] ||= begin
        sql = ActiveRecord::Base.sanitize_sql_array([
          'EXTRACT(EPOCH FROM (LEAST(COALESCE(exit_at, ?), ?) - GREATEST(entry_at, ?)))',
          now, session.ends_at, session.starts_at
        ])
        event.rfid_visits.where.not(ticket_id: nil)
             .where('entry_at < ? AND COALESCE(exit_at, ?) > ?', session.ends_at, now, session.starts_at)
             .group(:ticket_id).sum(Arel.sql(sql))
             .transform_values { |value| value.to_f.round }
      end
    end

    def session_row(session)
      seconds = seconds_for(session)
      registered = tickets.map(&:id).to_set
      need = need_seconds(session)
      {
        id: session.id, name: session.name, mandatory: session.mandatory,
        starts_at: Wire.time(session.starts_at), ends_at: Wire.time(session.ends_at),
        duration_seconds: session.duration_seconds, status: session_status(session),
        present: seconds.count { |id, value| registered.include?(id) && value.positive? },
        attended: seconds.count { |id, value| registered.include?(id) && value >= need },
        required_seconds: need
      }
    end

    def session_visits(session)
      event.rfid_visits.where.not(ticket_id: nil)
           .where('entry_at < ? AND COALESCE(exit_at, ?) > ?', session.ends_at, now, session.starts_at)
           .order(:entry_at).to_a
    end

    def attendee_row(ticket, visits, session, need)
      segments = visits.map do |visit|
        from = [visit.entry_at, session.starts_at].max
        to = [visit.exit_at || now, session.ends_at].min
        { in: Wire.time(from), out: Wire.time(to), seconds: (to - from).round,
          open: visit.exit_at.nil? && now < session.ends_at }
      end
      seconds = segments.sum { |segment| segment[:seconds] }
      {
        id: ticket.id, ticket_public_id: ticket.public_id, ticket_name: ticket.attendee_name,
        ticket_type: ticket.ticket_type&.name, ticket_type_id: ticket.ticket_type_id, seconds: seconds,
        percent: [(seconds * 10_000 / session.duration_seconds) / 100.0, 100].min,
        attended: seconds >= need, visit_count: segments.length,
        first_in: segments.first[:in], last_out: segments.last[:out],
        still_inside: segments.any? { |segment| segment[:open] }, segments: segments
      }
    end

    def matches_query?(row, ticket, query)
      needle = query.to_s.strip.downcase
      [row[:ticket_name], row[:ticket_public_id], ticket.attendee_email, ticket.attendee_phone]
        .compact.any? { |value| value.to_s.downcase.include?(needle) }
    end

    def session_status(session)
      return 'upcoming' if now < session.starts_at
      return 'live' if now < session.ends_at

      'ended'
    end

    def eligibility_row(ticket, required, feedback_ids, override)
      per_session = required.map do |session|
        secs = seconds_for(session)[ticket.id].to_i
        { session_id: session.id, percent: [(secs * 10_000 / session.duration_seconds) / 100.0, 100].min,
          met: secs >= need_seconds(session), ended: now >= session.ends_at }
      end
      feedback = feedback_ids.include?(ticket.id)
      {
        id: ticket.id, ticket_public_id: ticket.public_id, ticket_name: ticket.attendee_name,
        ticket_type: ticket.ticket_type&.name, ticket_type_id: ticket.ticket_type_id,
        feedback_submitted: feedback,
        sessions_met: override.present? || per_session.all? { |item| item[:met] },
        sessions: per_session.map { |item| item.slice(:session_id, :percent, :met) },
        override: override && { reason: override.reason, at: Wire.time(override.created_at) },
        status: eligibility_status(per_session, feedback, overridden: override.present?)
      }
    end

    def eligibility_status(per_session, feedback, overridden: false)
      return(feedback ? 'qualified' : 'needs_feedback') if overridden
      return 'not_qualified' if per_session.any? { |item| item[:ended] && !item[:met] }
      return 'in_progress' unless per_session.all? { |item| item[:met] }

      feedback ? 'qualified' : 'needs_feedback'
    end
  end
end
