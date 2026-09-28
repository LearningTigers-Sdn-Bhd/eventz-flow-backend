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

    def summary
      {
        headcount: event.rfid_visits.open.distinct.count(:ticket_id),
        open_visits: event.rfid_visits.open.count,
        anomaly_count: anomaly_observations.count + anomaly_visits.count,
        last_observed_at: Wire.time(event.rfid_observations.maximum(:captured_at))
      }
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

    def bindings
      event.rfid_bindings.order(:captured_at, :id).map do |binding|
        {
          id: binding.id, ticket_public_id: binding.ticket_public_id,
          ticket_name: binding.ticket_name, protocol: binding.protocol,
          uid_raw_hex: binding.uid_raw_hex, tag_key: binding.tag_key, mode: binding.mode,
          active: binding.active?, captured_at: Wire.time(binding.captured_at),
          recorded_at: Wire.time(binding.recorded_at), revoked_at: Wire.time(binding.revoked_at),
          revocation_reason: binding.revocation_reason
        }
      end
    end

    def visits_scope
      event.rfid_visits.includes(ticket: :ticket_type).order(entry_at: :desc, id: :desc)
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
    def anomaly_observations
      event.rfid_observations.includes(:station, :ticket)
           .where.not(outcome: %w[accepted possible_duplicate])
           .or(event.rfid_observations.where("jsonb_array_length(anomalies) > 0"))
           .or(event.rfid_observations.where("original_response ->> 'outcome' <> outcome"))
           .order(captured_at: :desc, station_id: :asc, delivery_id: :asc)
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

    private

    def cell_for(value)
      text = value.is_a?(Array) ? value.join(' ') : value.to_s
      text = "'#{text}" if text.match?(FORMULA_LEAD)
      text
    end
  end
end
