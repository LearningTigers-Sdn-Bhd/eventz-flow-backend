require 'digest'

module Rfid
  # One "put this sticker on this ticket" operation.
  #
  # First committed binding wins. Every write for an event takes the event row
  # lock, so two offline desks racing the same sticker are decided by the order
  # Rails commits them in — never by the `captured_at` a client claims, which
  # would make an already-acknowledged binding retroactively wrong. A later,
  # conflicting operation gets a typed 409 and the holder within the keyed
  # event; only an explicit, reasoned replacement revokes anything.
  #
  # Returns `[status, body]`, and saves the body for `(event, operation_id)` so
  # a retry cannot revoke the binding that replaced it.
  class Bind
    Request = Struct.new(:public_id, :protocol, :uid_raw_hex, :mode, :payload_version,
                         :operation_id, :captured_at, :replace, :reason, keyword_init: true)

    def self.call(event:, station:, request:)
      new(event: event, station: station, request: request).call
    end

    def initialize(event:, station:, request:)
      @event = event
      @station = station
      @request = request
    end

    def call
      event.with_lock do
        if replay = BindingOperation.find_by(event_id: event.id, operation_id: request.operation_id)
          unless replay.request_digest == digest
            return typed_error(400, 'malformed',
                               'this operation id was already used with a different request')
          end

          return [200, replay.original_response]
        end

        ticket = event.tickets.find_by(public_id: request.public_id)
        return typed_error(404, 'ticket_not_found', 'ticket not found') if ticket.nil?
        return typed_error(422, 'ticket_cancelled', 'ticket cancelled') if ticket.canceled?
        return typed_error(422, 'ticket_unpaid', 'ticket unpaid') unless ticket.paid?

        key = Wire.tag_key(request.uid_raw_hex, uid_rule)
        return typed_error(400, 'malformed', 'uid_raw_hex is not valid hex') if key.nil?

        if (held = active_for_tag(key)) && held.ticket_public_id == request.public_id
          # The same sticker on the same ticket through a new operation: nothing
          # to change, but the operation itself is still saved for replay.
          return save_reply(200, binding_body(held, []))
        end

        if request.replace
          if request.reason.blank?
            return typed_error(422, 'reason_required', 'a reason is required to replace')
          end
        elsif held
          return [409, Wire.error('uid_bound_elsewhere', 'sticker is linked to another ticket',
                                  holder: holder_ticket(held), binding: held)]
        elsif (own = active_for_ticket(ticket.id))
          return [409, Wire.error('ticket_has_sticker', 'ticket already has a sticker',
                                  binding: own)]
        end

        revoked = [held, active_for_ticket(ticket.id)].compact.uniq
        revoked.each do |binding|
          binding.update!(revoked_at: Time.current, revocation_reason: request.reason)
        end

        binding = Binding.create!(
          event: event, ticket: ticket, ticket_public_id: ticket.public_id,
          ticket_name: ticket.attendee_name, protocol: request.protocol,
          uid_raw_hex: Wire.normalize_uid(request.uid_raw_hex), tag_key: key,
          mode: request.mode, payload_version: request.payload_version,
          captured_at: request.captured_at, operation_id: request.operation_id
        )

        # A binding can explain gate readings that arrived before it (an offline
        # desk drains late): re-measure them and rebuild the visits here, while
        # the event lock is already held.
        Visits.reconcile_locked!(event: event, tag_key: key)

        save_reply(201, binding_body(binding, revoked))
      end
    end

    private

    attr_reader :event, :station, :request

    def uid_rule
      station&.uid_rule || 'as_is'
    end

    def active_for_tag(tag_key)
      Binding.active.find_by(event_id: event.id, tag_key: tag_key)
    end

    def active_for_ticket(ticket_id)
      Binding.active.find_by(event_id: event.id, ticket_id: ticket_id)
    end

    def holder_ticket(binding)
      event.tickets.find_by(public_id: binding.ticket_public_id)
    end

    def binding_body(binding, revoked)
      {
        binding: Wire.binding_info(binding),
        revoked: revoked.map { |row| Wire.binding_info(row) }
      }
    end

    def save_reply(status, body)
      BindingOperation.create!(event: event, operation_id: request.operation_id,
                               request_digest: digest, original_response: body)
      [status, body]
    end

    def digest
      @digest ||= Digest::SHA256.hexdigest(
        JSON.generate('public_id' => request.public_id, 'protocol' => request.protocol,
                      'uid_raw_hex' => Wire.normalize_uid(request.uid_raw_hex),
                      'mode' => request.mode, 'payload_version' => request.payload_version,
                      'operation_id' => request.operation_id,
                      'captured_at' => Wire.time(request.captured_at),
                      'replace' => request.replace, 'reason' => request.reason)
      )
    end

    def typed_error(status, code, message)
      [status, Wire.error(code, message)]
    end
  end
end
