require 'digest'

module Rfid
  # One desk check-in operation, idempotent by (event, operation_id).
  #
  # The event row is the serialization point: every write for an event takes
  # that lock, so two desks racing the same guest — or the same operation id
  # arriving twice — resolve one at a time, and the reply saved with the first
  # order is the reply the retry gets.
  #
  # Returns `[status, body]`. A repeated operation whose request content
  # differs is a typed `malformed` 400 and changes nothing.
  class DeskScan
    Request = Struct.new(:public_id, :operation_id, :captured_at, keyword_init: true)

    def self.call(event:, request:)
      new(event: event, request: request).call
    end

    def initialize(event:, request:)
      @event = event
      @request = request
    end

    def call
      event.with_lock do
        if replay = DeskOperation.find_by(event_id: event.id, operation_id: request.operation_id)
          unless replay.request_digest == digest
            return [400, Wire.error('malformed',
                                    'this operation id was already used with a different request')]
          end

          return [200, replay.original_response]
        end

        ticket = event.tickets.find_by(public_id: request.public_id)
        return typed_error(404, 'ticket_not_found', 'ticket not found') if ticket.nil?
        return typed_error(422, 'ticket_cancelled', 'ticket cancelled') if ticket.canceled?
        return typed_error(422, 'ticket_unpaid', 'ticket unpaid') unless ticket.paid?

        status, _log, first_check_in = ScanGate.record!(
          ticket, source: :rfid_desk, at: request.captured_at, operation_id: request.operation_id
        )
        return typed_error(422, 'ticket_unpaid', 'ticket unpaid') if status == :unpaid

        if status == :blocked
          # Even a blocked repeat owns its operation ID. Replays must keep the
          # original answer and cannot reuse that ID to scan another ticket.
          body = response_body(ticket, result: 'already_checked_in',
                                       checked_in_at: ticket.check_in_at)
          DeskOperation.create!(event: event, operation_id: request.operation_id,
                                request_digest: digest, original_response: body)
          return [200, body]
        end

        result = first_check_in ? 'checked_in' : 'already_checked_in'
        body = response_body(ticket, result: result, checked_in_at: ticket.check_in_at)
        DeskOperation.create!(event: event, operation_id: request.operation_id,
                              request_digest: digest, original_response: body)

        # A check-in can explain gate readings that were captured after it but
        # delivered before it; re-measure the ticket's readings and rebuild the
        # visits while the event lock is already held.
        Visits.reconcile_locked!(event: event, ticket_id: ticket.id) if first_check_in

        [200, body]
      end
    end

    private

    attr_reader :event, :request

    # The content of the request, so the same operation id with a different
    # guest, capture time or ticket is refused instead of answered with
    # somebody else's reply.
    def digest
      @digest ||= Digest::SHA256.hexdigest(
        JSON.generate('public_id' => request.public_id,
                      'operation_id' => request.operation_id,
                      'captured_at' => Wire.time(request.captured_at))
      )
    end

    def response_body(ticket, result:, checked_in_at:)
      {
        ticket: Wire.ticket(ticket),
        binding: Wire.binding_info(active_binding(ticket)),
        check_in: { result: result, checked_in_at: Wire.time(checked_in_at) }
      }
    end

    def active_binding(ticket)
      Binding.active.find_by(event_id: event.id, ticket_id: ticket.id)
    end

    def typed_error(status, code, message)
      [status, Wire.error(code, message)]
    end
  end
end
