module V1
  module Rfid
    # POST /v1/rfid/bindings          — link a sticker to a ticket
    # GET  /v1/rfid/bindings/lookup   — who holds this sticker right now?
    #
    # Lookup answers for the keyed event only, and a supplied protocol must
    # match the active binding; a mismatch is answered with nulls rather than a
    # conflict, because the client asked a question and the answer is "nobody".
    class BindingsController < BaseController
      def create
        body = parsed_body
        request = ::Rfid::Bind::Request.new(
          public_id: uuid_field(body, 'public_id'),
          protocol: enum_field(body, 'protocol', ::Rfid::Binding::PROTOCOLS),
          uid_raw_hex: uid_hex_field(body),
          mode: enum_field(body, 'mode', ::Rfid::Binding::MODES),
          payload_version: payload_version_field(body),
          operation_id: uuid_field(body, 'operation_id'),
          captured_at: time_field(body, 'captured_at'),
          replace: boolean_field(body, 'replace'),
          reason: optional_string_field(body, 'reason', max: 255)
        )

        status, payload = ::Rfid::Bind.call(event: rfid_event, station: rfid_station,
                                           request: request)
        render json: payload, status: status
      end

      def lookup
        uid_raw_hex = params[:uid_raw_hex]
        raise MalformedRequest, 'uid_raw_hex is required' unless uid_raw_hex.is_a?(String)

        protocol = params[:protocol]
        if protocol.present? && !::Rfid::Binding::PROTOCOLS.include?(protocol)
          raise MalformedRequest, "protocol must be one of #{::Rfid::Binding::PROTOCOLS.join(', ')}"
        end

        key = ::Rfid::Wire.tag_key(uid_raw_hex, uid_rule)
        raise MalformedRequest, 'uid_raw_hex must be even-length hex' if key.nil?

        binding = ::Rfid::Binding.active.find_by(event_id: rfid_event.id, tag_key: key)
        binding = nil if binding && protocol.present? && binding.protocol != protocol

        render json: {
          binding: ::Rfid::Wire.binding_info(binding),
          holder: binding && holder_for(binding)
        }, status: :ok
      end

      private

      # The sticker payload version is only meaningful for a written sticker,
      # and this release only knows version 1.
      def payload_version_field(body)
        version = body['payload_version']
        mode = body['mode']

        if mode == 'written'
          unless version == 1
            raise MalformedRequest, 'payload_version must be 1 for a written sticker'
          end
        elsif !version.nil?
          raise MalformedRequest, 'payload_version is only sent for a written sticker'
        end

        version
      end

      def holder_for(binding)
        ticket = rfid_event.tickets.find_by(public_id: binding.ticket_public_id)
        ticket && ::Rfid::Wire.ticket(ticket)
      end
    end
  end
end
