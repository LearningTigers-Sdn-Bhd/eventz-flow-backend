module Rfid
  # What one raw reading means for this event, right now.
  #
  # Everything here is derived from immutable facts — the raw reading, the
  # binding chain and the ticket — and nothing consults the saved
  # `original_response`, so the same reading can be re-measured later without
  # rewriting what the gate was first told.
  #
  # Historical validity is by *capture time*, never by delivery order: a
  # reading captured before the winning binding existed stays unknown, and a
  # reading captured after the binding that replaced it belongs to the
  # replacement.
  class Adjudicate
    Result = Struct.new(:outcome, :anomalies, :display, :ticket_id, keyword_init: true) do
      def to_wire(delivery_id)
        { delivery_id: delivery_id, outcome: outcome, anomalies: anomalies, display: display }
      end
    end

    UNKNOWN_REASON = 'sticker not linked to a ticket'
    REVOKED_REASON = 'sticker was replaced'
    EMPTY_DISPLAY = { name: nil, ticket_type: nil, reason: nil }.freeze

    def self.call(event:, observation:)
      new(event: event, observation: observation).call
    end

    def initialize(event:, observation:)
      @event = event
      @observation = observation
    end

    def call
      anomalies = []
      anomalies << 'role_mismatch' if role_mismatch?

      # A valid payload names a ticket. If that ticket is another event's, this
      # reading is not ours to identify, and the answer carries no holder.
      if payload_ticket && payload_ticket.event_id != event.id
        return result('wrong_event', anomalies, EMPTY_DISPLAY, nil)
      end

      binding = binding_at_capture
      if binding.nil?
        if known_tag?
          return result('revoked_tag', anomalies, display(reason: REVOKED_REASON), nil)
        end

        return result('unknown_tag', anomalies, display(reason: UNKNOWN_REASON), nil)
      end

      ticket = event.tickets.find_by(id: binding.ticket_id)
      holder = display(name: ticket&.attendee_name || binding.ticket_name,
                       ticket_type: ticket&.ticket_type&.name)

      if payload_ticket && payload_ticket.id != ticket&.id
        anomalies << 'payload_binding_mismatch'
        return result('ticket_invalid', anomalies, holder, ticket&.id)
      end

      return result('ticket_invalid', anomalies, holder, ticket&.id) if ticket.nil?
      return result('ticket_invalid', anomalies, holder, ticket.id) unless Wire.valid?(ticket)

      if observation.role == 'entry' && !checked_in_at_capture?(ticket)
        return result('not_checked_in', anomalies, holder, ticket.id) if event.rfid_require_check_in?

        anomalies << 'entered_without_check_in'
      end

      result('accepted', anomalies, holder, ticket.id)
    end

    private

    attr_reader :event, :observation

    def result(outcome, anomalies, display, ticket_id)
      Result.new(outcome: outcome, anomalies: anomalies, display: display, ticket_id: ticket_id)
    end

    def display(name: nil, ticket_type: nil, reason: nil)
      { name: name, ticket_type: ticket_type, reason: reason }
    end

    # Vendor byte 0 is the meeting-gate demo's "IN"; it is unverified on real
    # hardware, so a disagreement is only ever flagged, never obeyed.
    def role_mismatch?
      direction = observation.device_direction_raw
      return false if direction.nil?

      (direction.to_i.zero? ? 'entry' : 'exit') != observation.role
    end

    def payload_ticket
      public_id = observation.payload_public_id
      return nil if public_id.blank?

      @payload_ticket ||= Ticket.with_deleted.find_by(public_id: public_id)
    end

    # A ticket counts as checked in at capture time only when the first
    # check-in happened at or before the reading, so a delayed desk delivery
    # can still explain a gate read that came after it.
    def checked_in_at_capture?(ticket)
      return false unless ticket.checked_in?

      ticket.check_in_at.nil? || ticket.check_in_at <= observation.captured_at
    end

    def binding_at_capture
      at = observation.captured_at
      chain = event.rfid_bindings.where(tag_key: observation.tag_key).order(:id).to_a
      chain.each_with_index.reverse_each do |binding, index|
        next if binding.captured_at > at

        replacement = chain[index + 1]
        next if replacement && replacement.captured_at <= at
        next if replacement_for_ticket_at?(binding, at)

        return binding
      end
      nil
    end

    def replacement_for_ticket_at?(binding, at)
      return false unless binding.ticket_id

      event.rfid_bindings.where(ticket_id: binding.ticket_id)
           .where.not(tag_key: binding.tag_key)
           .where('id > ? AND captured_at <= ?', binding.id, at).exists?
    end

    # Was this sticker ever linked to something before the reading?
    def known_tag?
      event.rfid_bindings.where(tag_key: observation.tag_key)
           .where('captured_at <= ?', observation.captured_at).exists?
    end
  end
end
