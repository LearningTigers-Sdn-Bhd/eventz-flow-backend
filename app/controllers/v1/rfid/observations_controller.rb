module V1
  module Rfid
    # POST /v1/rfid/observations
    #
    # A batch of gate readings. Malformed entries, an oversized batch or a
    # delivery id reused with different content are refused whole: a partially
    # stored batch would leave the gate's own record of what it sent false.
    class ObservationsController < BaseController
      rescue_from ::Rfid::Observe::ContentConflict, with: :render_content_conflict

      def create
        body = parsed_body
        entries = body['observations']
        raise MalformedRequest, 'observations must be an array' unless entries.is_a?(Array)

        if entries.length > ::Rfid::Observe::MAX_BATCH
          return render_typed_error(
            'batch_too_large',
            "at most #{::Rfid::Observe::MAX_BATCH} observations per batch",
            status: :unprocessable_content
          )
        end

        # The station row is part of the evidence each observation cites, so a
        # station that never heartbeated cannot post readings at all.
        if rfid_station.nil?
          return render_typed_error(
            'malformed', 'this station must send a heartbeat before sending observations',
            status: :bad_request
          )
        end

        items = entries.map { |entry| parse_item(entry) }
        results = ::Rfid::Observe.call(event: rfid_event, station: rfid_station, items: items)

        render json: { results: results }, status: :ok
      end

      private

      def render_content_conflict
        render_typed_error('malformed', 'this delivery id was already used with different content',
                           status: :bad_request)
      end

      def parse_item(entry)
        raise MalformedRequest, 'each observation must be an object' unless entry.is_a?(Hash)

        uid_raw_hex = uid_hex_field(entry)
        payload_hex = optional_hex_field(entry, 'payload_hex', max: 128)

        ::Rfid::Observe::Item.new(
          delivery_id: uuid_field(entry, 'delivery_id'),
          role: enum_field(entry, 'role', ::Rfid::Observation::ROLES),
          protocol: enum_field(entry, 'protocol', ::Rfid::Observation::PROTOCOLS),
          uid_raw_hex: uid_raw_hex,
          tag_key: ::Rfid::Wire.tag_key(uid_raw_hex, uid_rule),
          payload_hex: payload_hex,
          payload_public_id: payload_hex && ::Rfid::Wire.decode_payload(payload_hex),
          device_direction_raw: optional_integer_field(entry, 'device_direction_raw', min: 0, max: 255),
          device_time_raw_hex: optional_hex_field(entry, 'device_time_raw_hex', max: 64),
          device_record_seq: optional_integer_field(entry, 'device_record_seq', min: 0, max: 2**64 - 1),
          flags_raw: flags_field(entry),
          captured_at: time_field(entry, 'captured_at')
        )
      end

      def optional_hex_field(entry, key, max:)
        value = entry[key]
        return nil if value.nil?
        raise MalformedRequest, "#{key} must be a string" unless value.is_a?(String)

        text = value.strip
        unless text.length.between?(2, max) && text.length.even? &&
               text.match?(/\A[0-9a-fA-F]+\z/)
          raise MalformedRequest, "#{key} must be even-length hex of at most #{max / 2} bytes"
        end

        text
      end

      # Vendor diagnostics, stored as evidence. Bounded so one request cannot
      # grow a jsonb column without limit.
      def flags_field(entry)
        value = entry['flags_raw']
        return nil if value.nil?

        raise MalformedRequest, 'flags_raw is too large' if JSON.generate(value).bytesize > 4096

        value
      end
    end
  end
end
