module Rfid
  # Session attendance and e-certificate eligibility, derived from the gate
  # visits. Nothing is scanned per session: a guest's time in a session is how
  # long their visits overlap its window (an open visit counts up to `now`,
  # never past the session end).
  #
  # A guest "attended" a session when that overlap is at least
  # `event.rfid_attendance_percent` of the session's length. They qualify for
  # the e-certificate when they attended every *mandatory* session and have
  # submitted the event's feedback form.
  class Attendance
    STATUSES = %w[qualified needs_feedback in_progress not_qualified].freeze

    def self.qualified_ticket_ids(event)
      new(event).eligibility_rows.select { |row| row[:status] == 'qualified' }.map { |row| row[:id] }
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
    def filter_rows(rows, query: nil, ticket_type_id: nil)
      by_id = tickets.index_by(&:id)
      rows = rows.select { |row| row[:ticket_type_id].to_s == ticket_type_id.to_s } if ticket_type_id.present?
      rows = rows.select { |row| matches_query?(row, by_id[row[:id]], query) } if query.present?
      rows
    end

    def ticket_types
      event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } }
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
        tickets.map { |ticket| eligibility_row(ticket, required, feedback_ids) }
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
        percent: [(seconds * 100.0 / session.duration_seconds).round, 100].min,
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

    def eligibility_row(ticket, required, feedback_ids)
      per_session = required.map do |session|
        secs = seconds_for(session)[ticket.id].to_i
        { session_id: session.id, percent: [(secs * 100.0 / session.duration_seconds).round, 100].min,
          met: secs >= need_seconds(session), ended: now >= session.ends_at }
      end
      feedback = feedback_ids.include?(ticket.id)
      {
        id: ticket.id, ticket_public_id: ticket.public_id, ticket_name: ticket.attendee_name,
        ticket_type: ticket.ticket_type&.name, ticket_type_id: ticket.ticket_type_id,
        feedback_submitted: feedback,
        sessions: per_session.map { |item| item.slice(:session_id, :percent, :met) },
        status: eligibility_status(per_session, feedback)
      }
    end

    def eligibility_status(per_session, feedback)
      return 'not_qualified' if per_session.any? { |item| item[:ended] && !item[:met] }
      return 'in_progress' unless per_session.all? { |item| item[:met] }

      feedback ? 'qualified' : 'needs_feedback'
    end
  end
end
