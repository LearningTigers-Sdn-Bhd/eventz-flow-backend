module V1
  module Rfid
    # Base for the seven RfiDex device routes.
    #
    # The device API is keyed by the RFID key alone: the event comes from the
    # key and never from the URL or the body, so the generic event-parameter
    # guard is skipped here (it would read an event out of a body `public_id`
    # and answer with the generic API error shape instead of the device one).
    # Authentication and the method/path scope guard still run.
    class BaseController < ApplicationController
      skip_before_action :enforce_api_key_event_scope!
      before_action :require_rfid_device_key!
      before_action :require_station_header!

      # 1-128 printable ASCII. Production RfiDex sends a UUID; the shared
      # contract tests send `desk-contract`; the header is opaque either way.
      STATION_KEY_RE = /\A[\x20-\x7E]{1,128}\z/.freeze

      # Raised by the field readers below; every one of them is a typed
      # `malformed` 400 rather than a Rails validation error.
      class MalformedRequest < StandardError; end

      rescue_from MalformedRequest, with: :render_malformed

      attr_reader :rfid_event, :station_key

      private

      def require_rfid_device_key!
        return if current_api_key.present? &&
                  current_api_key.scope == ApiKey::RFID_SCOPE &&
                  current_api_key.event_id.present?

        render_typed_error('unauthorized', 'an event-scoped rfid key is required',
                           status: :unauthorized)
      end

      # The only source of the event on a device route.
      def rfid_event
        @rfid_event ||= Event.find(current_api_key.event_id)
      end

      # The station that sent this request, if it has heartbeated yet. Bindings
      # only need its UID rule (and default to `as_is` without one); the
      # observation routes, whose rows reference the station, require the row.
      def rfid_station
        return @rfid_station if defined?(@rfid_station)

        @rfid_station = ::Rfid::Station.find_by(event_id: rfid_event.id, station_key: station_key)
      end

      def uid_rule
        rfid_station&.uid_rule || 'as_is'
      end

      def require_station_header!
        value = request.headers['X-RfiDex-Station'].to_s
        unless value.match?(STATION_KEY_RE) && !value.strip.empty?
          return render_typed_error(
            'malformed', 'X-RfiDex-Station must be 1-128 printable ASCII characters',
            status: :bad_request
          )
        end

        @station_key = value
      end

      def render_malformed(error)
        render_typed_error('malformed', error.message, status: :bad_request)
      end

      def render_typed_error(code, message, status:, holder: nil, binding: nil)
        render json: ::Rfid::Wire.error(code, message, holder: holder, binding: binding),
               status: status
      end

      # --- Request body readers -------------------------------------------------
      # They mirror the Rust request structs: required fields must be present
      # and typed, optional fields may be absent or null, unknown fields are
      # ignored (serde ignores them too).

      def parsed_body
        @parsed_body ||= begin
          raw = request.raw_post
          raise MalformedRequest, 'a JSON object body is required' if raw.blank?

          parsed = JSON.parse(raw)
          raise MalformedRequest, 'body must be a JSON object' unless parsed.is_a?(Hash)

          parsed
        end
      rescue JSON::ParserError
        raise MalformedRequest, 'body is not valid JSON'
      end

      def string_field(body, key, max: 255)
        value = body[key]
        raise MalformedRequest, "#{key} is required" unless value.is_a?(String)

        value = value.strip
        if value.empty? || value.length > max
          raise MalformedRequest, "#{key} must be 1-#{max} characters"
        end

        value
      end

      def enum_field(body, key, allowed)
        value = body[key]
        allowed.include?(value) || raise(MalformedRequest.new(
                                           "#{key} must be one of #{allowed.join(', ')}"
                                         ))
        value
      end

      def optional_enum_field(body, key, allowed)
        value = body[key]
        return nil if value.nil?

        enum_field(body, key, allowed)
      end

      def optional_string_field(body, key, max: 255)
        value = body[key]
        return nil if value.nil?
        raise MalformedRequest, "#{key} must be a string" unless value.is_a?(String)

        value = value.strip
        return nil if value.empty?
        raise MalformedRequest, "#{key} must be at most #{max} characters" if value.length > max

        value
      end

      def uuid_field(body, key)
        validate_uuid(body[key], key)
      end

      def validate_uuid(value, label)
        raise MalformedRequest, "#{label} must be a UUID" unless value.is_a?(String) && value.match?(UUID_RE)

        value.downcase
      end

      def optional_uuid_field(body, key)
        return nil if body[key].nil?

        uuid_field(body, key)
      end

      # RFC3339 with a zone, which is what `chrono` sends. A timestamp without
      # a zone is rejected rather than guessed at.
      def time_field(body, key)
        value = body[key]
        raise MalformedRequest, "#{key} is required" unless value.is_a?(String)

        begin
          Time.iso8601(value).utc
        rescue ArgumentError
          raise MalformedRequest, "#{key} must be an RFC3339 timestamp"
        end
      end

      def integer_field(body, key, min: 0, max: 2**63 - 1)
        value = body[key]
        unless value.is_a?(Integer) && value.between?(min, max)
          raise MalformedRequest, "#{key} must be an integer between #{min} and #{max}"
        end

        value
      end

      def optional_integer_field(body, key, min: 0, max: 2**63 - 1)
        return nil if body[key].nil?

        integer_field(body, key, min: min, max: max)
      end

      def boolean_field(body, key)
        value = body[key]
        return false if value.nil?
        raise MalformedRequest, "#{key} must be true or false" unless [true, false].include?(value)

        value
      end

      # One byte to UID_HEX_MAX/2 bytes of hex, as `rfidex-core::tag::parse_hex`
      # accepts it.
      def uid_hex_field(body, key = 'uid_raw_hex')
        value = body[key]
        raise MalformedRequest, "#{key} is required" unless value.is_a?(String)

        text = value.strip
        unless text.length.between?(2, UID_HEX_MAX) && text.length.even? &&
               text.match?(/\A[0-9a-fA-F]+\z/)
          raise MalformedRequest, "#{key} must be 1-#{UID_HEX_MAX / 2} bytes of hex"
        end

        text
      end

      UID_HEX_MAX = 64
      UUID_RE = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/.freeze
    end
  end
end
