require 'csv'

module Rfid
  # Event-scoped staff reads: the live summary, the raw device history and the
  # visit CSV.
  #
  # Everything is read from the current adjudication and the visit projection.
  # Nothing here re-derives facts for the device API or writes anything, and no
  # full contact value or key ever appears in a row.
  class Report
    CSV_HEADERS = %w[
      ticket_public_id ticket_name ticket_type entry_at exit_at duration_seconds
      status manual anomalies entry_station exit_station
    ].freeze

    # A cell that starts like a formula (or with a tab/newline) is prefixed with
    # an apostrophe so a spreadsheet shows the text instead of evaluating it.
    FORMULA_LEAD = /\A[=+\-@\t\r\n]/.freeze

    def initialize(event)
      @event = event
    end

    attr_reader :event

    MISSED_REASONS = %w[no_tag no_read].freeze

    # `ticket_type_id` narrows the attendance figures (registered, checked in,
    # gate-scanned, inside, outside, missed scans) to one ticket type. Anomalies
    # and the last gate read stay event-wide: they are about the gates.
    def summary(ticket_type_id: nil)
      tickets = registered_tickets
      tickets = tickets.where(ticket_type_id: ticket_type_id) if ticket_type_id.present?
      open_visits = event.rfid_visits.open
      open_visits = open_visits.where(ticket_id: tickets.select(:id)) if ticket_type_id.present?

      registered = tickets.count
      checked_in = tickets.checked_in.count
      gate_scanned = tickets.where(id: visit_ticket_ids).count
      inside = tickets.where(id: open_visits.where.not(ticket_id: nil).select(:ticket_id)).count
      {
        headcount: open_visits.distinct.count(:ticket_id),
        open_visits: open_visits.count,
        anomaly_count: anomaly_observations.count + anomaly_visits.count,
        last_observed_at: Wire.time(event.rfid_observations.maximum(:captured_at)),
        registered: registered,
        checked_in: checked_in,
        not_arrived: registered - checked_in,
        gate_scanned: gate_scanned,
        inside: inside,
        outside: gate_scanned - inside,
        missed_scans: {
          no_tag: missed_scans_scope('no_tag', ticket_type_id: ticket_type_id).count,
          no_read: missed_scans_scope('no_read', ticket_type_id: ticket_type_id).count
        },
        ticket_types: event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } }
      }
    end

    # Checked in at the desk but never read by a gate. `no_tag`: no sticker is
    # linked, so a gate cannot see them. `no_read`: a sticker is linked and no
    # gate has read it yet (not entered, or the gate missed it).
    def missed_scans_scope(reason = nil, query: nil, ticket_type_id: nil)
      scope = registered_tickets.checked_in.where.not(id: visit_ticket_ids)
      scope = scope.where(ticket_type_id: ticket_type_id) if ticket_type_id.present?
      scope = search_tickets(scope, query) if query.present?
      bound = event.rfid_bindings.active.where.not(ticket_id: nil).select(:ticket_id)
      scope = scope.where.not(id: bound) if reason == 'no_tag'
      scope = scope.where(id: bound) if reason == 'no_read'
      scope.includes(:ticket_type).order(check_in_at: :desc, id: :desc)
    end

    def missed_scan_rows(tickets)
      bound = event.rfid_bindings.active.where(ticket_id: tickets.map(&:id)).pluck(:ticket_id)
      tickets.map do |ticket|
        {
          id: ticket.id, ticket_public_id: ticket.public_id, ticket_name: ticket.attendee_name,
          ticket_type: ticket.ticket_type&.name, checked_in_at: Wire.time(ticket.check_in_at),
          reason: bound.include?(ticket.id) ? 'no_read' : 'no_tag'
        }
      end
    end

    def stations
      event.rfid_stations.order(:station_key).map do |station|
        {
          id: station.id, station_key: station.station_key, name: station.name,
          kind: station.kind, role: station.role, uid_rule: station.uid_rule,
          hw_model: station.hw_model, firmware: station.firmware,
          app_version: station.app_version,
          last_heartbeat_at: Wire.time(station.last_heartbeat_at)
        }
      end
    end

    BINDING_STATUSES = %w[active revoked].freeze

    # Newest first; `query` matches the guest, ticket id or sticker, `status`
    # is active/revoked, `ticket_type_id` narrows by the ticket's type. The
    # caller paginates, so a big event never ships every binding at once.
    def bindings_scope(status: nil, query: nil, ticket_type_id: nil)
      scope = event.rfid_bindings.includes(ticket: :ticket_type).order(captured_at: :desc, id: :desc)
      scope = scope.where(revoked_at: nil) if status == 'active'
      scope = scope.where.not(revoked_at: nil) if status == 'revoked'
      scope = scope.where(ticket_id: event.tickets.where(ticket_type_id: ticket_type_id).select(:id)) if ticket_type_id.present?
      if query.present?
        like = "%#{Ticket.sanitize_sql_like(query.to_s.strip)}%"
        scope = scope.where('rfid_bindings.ticket_name ILIKE :q OR CAST(rfid_bindings.ticket_public_id AS text) ILIKE :q ' \
                            'OR rfid_bindings.tag_key ILIKE :q OR rfid_bindings.uid_raw_hex ILIKE :q', q: like)
      end
      scope
    end

    def binding_row(binding)
      {
        id: binding.id, ticket_public_id: binding.ticket_public_id,
        ticket_name: binding.ticket_name, ticket_type: binding.ticket&.ticket_type&.name,
        protocol: binding.protocol,
        uid_raw_hex: binding.uid_raw_hex, tag_key: binding.tag_key, mode: binding.mode,
        active: binding.active?, captured_at: Wire.time(binding.captured_at),
        recorded_at: Wire.time(binding.recorded_at), revoked_at: Wire.time(binding.revoked_at),
        revocation_reason: binding.revocation_reason
      }
    end

    def bindings
      bindings_scope.reverse_order.map { |binding| binding_row(binding) }
    end

    def ticket_types
      event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } }
    end

    def visits_scope
      event.rfid_visits.includes(ticket: :ticket_type).order(entry_at: :desc, id: :desc)
    end

    GUEST_STATUSES = %w[inside outside].freeze

    # One entry per guest: all their gate visits folded into totals, newest
    # activity first. Returns [groups_for_page, total_count].
    def guest_visits(status: nil, query: nil, ticket_type_id: nil, page: 1, per_page: 25, now: Time.current)
      scope = event.rfid_visits.where.not(ticket_id: nil)
      if ticket_type_id.present?
        scope = scope.where(ticket_id: event.tickets.where(ticket_type_id: ticket_type_id).select(:id))
      end
      scope = scope.where(ticket_id: search_tickets(event.tickets, query).select(:id)) if query.present?
      grouped = scope.group(:ticket_id)
      grouped = grouped.having('BOOL_OR(exit_at IS NULL)') if status == 'inside'
      grouped = grouped.having('NOT BOOL_OR(exit_at IS NULL)') if status == 'outside'
      ids = grouped.order(Arel.sql('MAX(GREATEST(entry_at, COALESCE(exit_at, entry_at))) DESC'))
                   .pluck(:ticket_id)
      page_ids = ids.slice((page - 1) * per_page, per_page) || []

      visits = event.rfid_visits.includes(ticket: :ticket_type, entry_observation: :station,
                                          exit_observation: :station)
                    .where(ticket_id: page_ids).order(:entry_at).to_a.group_by(&:ticket_id)
      groups = page_ids.map { |id| guest_group(visits.fetch(id, []), now) }
      [groups, ids.length]
    end

    def visit_row(visit)
      {
        id: visit.id, ticket_public_id: visit.ticket_public_id, ticket_name: visit.ticket_name,
        ticket_type: visit.ticket&.ticket_type&.name,
        entry_at: Wire.time(visit.entry_at), exit_at: Wire.time(visit.exit_at),
        duration_seconds: visit.duration_seconds, status: visit.open? ? 'open' : 'closed',
        manual: visit.manual, anomalies: visit.anomalies,
        entry_station: visit.entry_observation&.station&.station_key,
        exit_station: visit.exit_observation&.station&.station_key
      }
    end

    # Every reading a human should look at: anything the gate could not accept,
    # anything with an anomaly now, and anything whose meaning changed since the
    # reply the gate was first given. A duplicate delivery is not an anomaly —
    # it is the same fact delivered twice.
    #
    # A dismissed reading is hidden from the list and the count, never deleted.
    def anomaly_observations(include_dismissed: false)
      scope = event.rfid_observations.includes(:station, :ticket)
                   .where.not(outcome: %w[accepted possible_duplicate])
                   .or(event.rfid_observations.where("jsonb_array_length(anomalies) > 0"))
                   .or(event.rfid_observations.where("original_response ->> 'outcome' <> outcome"))
      scope = scope.where(dismissed_at: nil) unless include_dismissed
      scope.order(captured_at: :desc, station_id: :asc, delivery_id: :asc)
    end

    # Narrow the anomaly list by guest/ticket id/sticker, the reading's current
    # outcome and the station that read it.
    def filter_anomalies(scope, query: nil, outcome: nil, station: nil)
      scope = scope.where(outcome: outcome) if outcome.present?
      scope = scope.where(station_id: event.rfid_stations.where(station_key: station).select(:id)) if station.present?
      if query.present?
        like = "%#{Ticket.sanitize_sql_like(query.to_s.strip)}%"
        scope = scope.where('rfid_observations.tag_key ILIKE :q OR rfid_observations.ticket_id IN (:ids)',
                            q: like, ids: search_tickets(event.tickets, query).select(:id))
      end
      scope
    end

    def station_keys
      event.rfid_stations.order(:station_key).pluck(:station_key)
    end

    def anomaly_observation_row(observation)
      current = Adjudicate.call(event: event, observation: observation)
      {
        observation_id: observation.id, station_key: observation.station&.station_key,
        role: observation.role, tag_key: observation.tag_key,
        ticket_public_id: observation.ticket&.public_id,
        ticket_name: observation.ticket&.attendee_name,
        captured_at: Wire.time(observation.captured_at),
        original_outcome: observation.original_response['outcome'],
        current_outcome: observation.outcome,
        original_anomalies: observation.original_response['anomalies'] || [],
        anomalies: observation.anomalies,
        reason: current.display[:reason]
      }
    end

    def anomaly_visits
      event.rfid_visits.includes(ticket: :ticket_type, entry_observation: :station,
                                 exit_observation: :station)
           .where('jsonb_array_length(anomalies) > 0 OR manual = true')
           .order(entry_at: :desc, id: :desc)
    end

    def visit_rows(visits)
      visits.map { |visit| visit_row(visit) }
    end

    def visits_csv
      CSV.generate(headers: CSV_HEADERS, write_headers: true) do |csv|
        visits_scope.each do |visit|
          csv << visit_row(visit).values_at(*CSV_HEADERS.map(&:to_sym)).map { |cell| cell_for(cell) }
        end
      end
    end

    # Entries, exits and the running "inside" figure per time bucket, built
    # from the visit projection. Buckets are 15 min for a one-day event, hourly
    # for longer ones.
    def flow(from: nil, to: nil)
      visits = event.rfid_visits
      first = visits.minimum(:entry_at)
      return { interval_minutes: 15, buckets: [] } if first.nil?

      last = [visits.maximum(:entry_at), visits.maximum(:exit_at)].compact.max
      start = from || first
      stop = to || last
      return { interval_minutes: 15, buckets: [] } if stop <= start

      interval = flow_interval(stop - start)
      in_range = ->(column) { visits.where(column => start..stop) }
      entries = bucketed_counts(in_range.call(:entry_at), :entry_at, interval)
      exits = bucketed_counts(in_range.call(:exit_at), :exit_at, interval)

      # Guests already inside when the window opens.
      inside = visits.where('entry_at < ?', start).where('exit_at IS NULL OR exit_at >= ?', start).count
      buckets = (floor_to(start, interval)..floor_to(stop, interval)).step(interval).map do |epoch|
        inside = [inside + entries.fetch(epoch, 0) - exits.fetch(epoch, 0), 0].max
        { at: Wire.time(Time.zone.at(epoch)), entries: entries.fetch(epoch, 0),
          exits: exits.fetch(epoch, 0), inside: inside }
      end
      { interval_minutes: interval / 60, buckets: buckets }
    end

    private

    # 5 min for a short window, 15 min up to half a day, then hourly, then
    # coarser so a long event never returns thousands of points.
    def flow_interval(span)
      return 5.minutes.to_i if span <= 3.hours
      return 15.minutes.to_i if span <= 12.hours
      return 1.hour.to_i if span <= 14.days

      span <= 60.days ? 6.hours.to_i : 1.day.to_i
    end

    def floor_to(time, interval)
      (time.to_i / interval) * interval
    end

    def bucketed_counts(scope, column, interval)
      expr = Arel.sql("FLOOR(EXTRACT(EPOCH FROM #{column}) / #{interval.to_i}) * #{interval.to_i}")
      scope.group(expr).count.transform_keys(&:to_i)
    end

    # Name, email or phone fragment, or (part of) the ticket id.
    def guest_group(visits, now)
      first = visits.first
      closed_exits = visits.filter_map(&:exit_at)
      {
        ticket_id: first.ticket_id, ticket_public_id: first.ticket_public_id,
        ticket_name: first.ticket_name, ticket_type: first.ticket&.ticket_type&.name,
        visit_count: visits.length, first_in: Wire.time(first.entry_at),
        last_out: Wire.time(closed_exits.max),
        total_seconds: visits.sum { |visit| ((visit.exit_at || now) - visit.entry_at).round },
        status: visits.any?(&:open?) ? 'inside' : 'outside',
        manual: visits.any?(&:manual), anomalies: visits.flat_map(&:anomalies).uniq,
        visits: visits.reverse.map { |visit| visit_row(visit) }
      }
    end

    def search_tickets(scope, query)
      like = "%#{Ticket.sanitize_sql_like(query.to_s.strip)}%"
      scope.where('tickets.attendee_name ILIKE :q OR tickets.attendee_email ILIKE :q OR ' \
                  'tickets.attendee_phone ILIKE :q OR CAST(tickets.public_id AS text) ILIKE :q', q: like)
    end

    def registered_tickets
      event.tickets.active.paid
    end

    def visit_ticket_ids
      event.rfid_visits.where.not(ticket_id: nil).select(:ticket_id)
    end

    def cell_for(value)
      text = value.is_a?(Array) ? value.join(' ') : value.to_s
      text = "'#{text}" if text.match?(FORMULA_LEAD)
      text
    end
  end
end
