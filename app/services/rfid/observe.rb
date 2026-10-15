require 'digest'

module Rfid
  # A batch of gate readings.
  #
  # The whole batch is validated by the controller before this runs, so every
  # entry here is storable. Each entry is saved once per
  # `(station, delivery_id)` with the reply it was first given, and the event's
  # projection is refreshed once at the end — under the event lock, like every
  # other write for an event.
  class Observe
    MAX_BATCH = 50

    # One validated reading. `tag_key` was computed with the station's UID rule
    # at the moment of ingest, and `payload_public_id` is the ticket a valid v1
    # payload names (nil when the payload is absent or unreadable).
    Item = Struct.new(:delivery_id, :role, :protocol, :uid_raw_hex, :tag_key, :payload_hex,
                      :payload_public_id, :device_direction_raw, :device_time_raw_hex,
                      :device_record_seq, :flags_raw, :captured_at, keyword_init: true) do
      def device_metadata
        { 'device_direction_raw' => device_direction_raw,
          'device_time_raw_hex' => device_time_raw_hex,
          'flags_raw' => flags_raw }
      end
    end

    class ContentConflict < StandardError; end

    def self.call(event:, station:, items:)
      new(event: event, station: station, items: items).call
    end

    def initialize(event:, station:, items:)
      @event = event
      @station = station
      @items = items
    end

    # The per-entry results, in request order.
    def call
      results = []
      affected_tags = []
      affected_tickets = []

      event.with_lock do
        items.each do |item|
          if (stored = Observation.find_by(station_id: station.id, delivery_id: item.delivery_id))
            raise ContentConflict unless stored.request_digest == digest(item)

            results << stored.original_response
            next
          end

          outcome, anomalies, display, ticket_id = evaluate(item)
          observation = Observation.create!(
            event: event, station: station, ticket_id: ticket_id,
            delivery_id: item.delivery_id, device_record_seq: item.device_record_seq,
            role: item.role, protocol: item.protocol, uid_raw_hex: item.uid_raw_hex,
            tag_key: item.tag_key, payload_hex: item.payload_hex,
            payload_public_id: item.payload_public_id, captured_at: item.captured_at,
            recorded_at: Time.current, device_metadata: item.device_metadata,
            outcome: outcome, anomalies: anomalies,
            original_response: { 'delivery_id' => item.delivery_id, 'outcome' => outcome,
                                 'anomalies' => anomalies, 'display' => display },
            request_digest: digest(item)
          )

          results << observation.original_response
          affected_tags << observation.tag_key
          affected_tickets << ticket_id if ticket_id
        end

        moved = Visits.refresh_locked!(event: event, tag_keys: affected_tags.uniq,
                                      ticket_ids: affected_tickets.uniq)
        # Only the timelines this batch (or a re-measured older reading)
        # touched; a full-event rebuild here made every batch cost the whole
        # event's history while holding the lock.
        Visits.rebuild!(event: event, ticket_ids: (affected_tickets + moved).uniq)
      end

      results
    end

    private

    attr_reader :event, :station, :items

    def evaluate(item)
      # A repeat of a device sequence is a duplicate *delivery*: it keeps its
      # own saved reply and never becomes a second passage.
      if duplicate_sequence?(item)
        return ['possible_duplicate', [], Adjudicate::EMPTY_DISPLAY, nil]
      end

      result = Adjudicate.call(event: event, observation: item)
      [result.outcome, result.anomalies, result.display, result.ticket_id]
    end

    def duplicate_sequence?(item)
      return false if item.device_record_seq.nil?

      event.rfid_observations
           .where(station_id: station.id, device_record_seq: item.device_record_seq)
           .where.not(delivery_id: item.delivery_id)
           .exists?
    end

    def digest(item)
      Digest::SHA256.hexdigest(
        JSON.generate(item.to_h.merge(captured_at: Wire.time(item.captured_at)).stringify_keys)
      )
    end
  end
end
