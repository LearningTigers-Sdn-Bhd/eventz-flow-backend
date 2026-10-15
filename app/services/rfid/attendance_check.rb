module Rfid
  # Guests the gates may have missed, for staff to reach out to by WhatsApp.
  #
  # EventzFlow only fires the webhook; the event's webhook receiver (the
  # SalesCatalyst workflow) sends the message. Two groups, a guest is in at
  # most one:
  #
  #   never_detected         — checked in at the desk but no gate visit. A guest
  #                            who never checked in is a no-show, not "missing".
  #                            Some have no sticker, so no gate could see them.
  #   outside_during_session — has visits, none open, while a session is live
  #
  # `ticket_type_ids` narrows every group (keep VIPs and crew out).
  #
  # Each send is recorded as an `attendance_notice` correction, so the same
  # guest is not messaged again within RESEND_AFTER.
  class AttendanceCheck
    REASONS = %w[never_detected outside_during_session].freeze
    EVENT_TYPE = 'rfid.attendance_check'.freeze
    RESEND_AFTER = 1.hour

    def initialize(event, now: Time.current, ticket_type_ids: nil)
      @event = event
      @now = now
      @ticket_type_ids = ticket_type_ids
    end

    def summary
      {
        webhook_configured: event.webhook_urls.any?,
        ticket_types: event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } },
        live_session: live_session && { id: live_session.id, name: live_session.name,
                                        ends_at: Wire.time(live_session.ends_at) },
        groups: REASONS.to_h { |reason| [reason, group_counts(reason)] }
      }
    end

    # Fires one webhook per reachable guest in the chosen groups.
    def notify!(reasons:, actor:)
      targets = rows.select { |row| reasons.include?(row[:reason]) }
      sendable = targets.select { |row| sendable?(row) }
      sendable.each do |row|
        payload = payload_for(row)
        event.webhook_urls.each { |url| WebhookSenderJob.perform_later(url, payload) }
        Correction.create!(event: event, actor: actor, ticket: row[:ticket], kind: 'attendance_notice',
                           reason: 'WhatsApp attendance check', details: { 'reason' => row[:reason] })
      end
      { sent: sendable.length, skipped_no_phone: targets.count { |row| phone_missing?(row) },
        skipped_recent: targets.count { |row| !phone_missing?(row) && recent?(row) } }
    end

    private

    attr_reader :event, :now, :ticket_type_ids

    def sticker_ids
      @sticker_ids ||= event.rfid_bindings.where.not(ticket_id: nil).distinct.pluck(:ticket_id).to_set
    end

    def group_counts(reason)
      group = rows.select { |row| row[:reason] == reason }
      { total: group.length, sendable: group.count { |row| sendable?(row) },
        no_sticker: group.count { |row| !sticker_ids.include?(row[:ticket].id) },
        no_phone: group.count { |row| phone_missing?(row) },
        recently_notified: group.count { |row| !phone_missing?(row) && recent?(row) } }
    end

    def sendable?(row)
      !phone_missing?(row) && !recent?(row)
    end

    def phone_missing?(row)
      row[:ticket].attendee_phone.blank?
    end

    def recent?(row)
      recently_notified_ids.include?(row[:ticket].id)
    end

    def recently_notified_ids
      @recently_notified_ids ||= event.rfid_corrections
                                      .where(kind: 'attendance_notice').where('created_at > ?', now - RESEND_AFTER)
                                      .pluck(:ticket_id).to_set
    end

    def live_session
      @live_session ||= event.rfid_sessions.where('starts_at <= ? AND ends_at > ?', now, now)
                             .order(:ends_at).first
    end

    def rows
      @rows ||= begin
        visited = event.rfid_visits.where.not(ticket_id: nil)
        tickets = event.tickets.active.paid.includes(:ticket_type)
        tickets = tickets.where(ticket_type_id: ticket_type_ids) if ticket_type_ids
        never = tickets.where(checked_in: true).where.not(id: visited.select(:ticket_id)).map { |t| { ticket: t, reason: 'never_detected' } }
        outside = []
        if live_session
          outside = tickets.where(id: visited.select(:ticket_id))
                           .where.not(id: visited.open.select(:ticket_id))
                           .map { |t| { ticket: t, reason: 'outside_during_session' } }
        end
        never + outside
      end
    end

    def payload_for(row)
      ticket = row[:ticket]
      { event_type: EVENT_TYPE, webhook_id: SecureRandom.uuid, timestamp: now.utc.iso8601, api_version: 'v1',
        ticket: { id: ticket.id, public_id: ticket.public_id, attendee_name: ticket.attendee_name,
                  attendee_email: ticket.attendee_email, attendee_phone: ticket.attendee_phone },
        ticket_type: { id: ticket.ticket_type&.id, name: ticket.ticket_type&.name },
        has_sticker: sticker_ids.include?(ticket.id),
        event: { id: event.id, title: event.title },
        attendance_check: { reason: row[:reason],
                            session: row[:reason] == 'outside_during_session' && live_session ? session_json : nil } }
    end

    def session_json
      { id: live_session.id, name: live_session.name,
        starts_at: Wire.time(live_session.starts_at), ends_at: Wire.time(live_session.ends_at) }
    end
  end
end
