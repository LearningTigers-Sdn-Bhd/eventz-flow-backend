module Rfid
  # Org-owner clean-up and repair of RFID data.
  #
  # Every method takes the event lock, changes rows, then re-measures what the
  # change touched and rebuilds the visit projection, so headcount and visits
  # always match the readings that are left. Who did it is recorded by the
  # request activity log; nothing here writes its own audit row.
  #
  # Failures are `Rfid::Admin::Error` with a status the controller renders.
  class Admin
    class Error < StandardError
      attr_reader :status

      def initialize(message, status: :unprocessable_content)
        super(message)
        @status = status
      end
    end

    def initialize(event)
      @event = event
    end

    # The station, everything it recorded, and the visits built from those
    # readings.
    def delete_station!(station)
      event.with_lock do
        remove_observations!(event.rfid_observations.where(station_id: station.id).pluck(:id))
        station.destroy!
        Visits.rebuild!(event: event)
      end
    end

    # One visit and the readings it was built from: its entry and exit, plus
    # any repeated entries the ticket made while it was open (left behind they
    # would reappear as a new visit). A manual entry loses its correction too.
    # The station and the sticker binding are untouched.
    def delete_visit!(visit)
      event.with_lock do
        visit = event.rfid_visits.find_by(id: visit.id)
        raise Error.new('Visit not found.', status: :not_found) if visit.nil?

        event.rfid_corrections.where(id: visit.correction_id, kind: Visits::MANUAL_ENTRY).delete_all if visit.correction_id
        remove_observations!(visit_observation_ids(visit))
        Visits.rebuild!(event: event)
      end
    end

    # Hard delete. Earlier readings of that sticker are re-measured, so they
    # become unknown_tag.
    def delete_binding!(binding)
      event.with_lock do
        binding.destroy!
        Visits.reconcile_locked!(event: event, tag_key: binding.tag_key,
                                 ticket_id: binding.ticket_id)
      end
    end

    # Change the ticket and/or the sticker of an active binding in place.
    def update_binding!(binding, ticket_public_id: nil, tag_key: nil)
      event.with_lock do
        binding.reload
        raise Error.new('Only an active binding can be edited.') unless binding.active?

        old_tag_key = binding.tag_key
        old_ticket_id = binding.ticket_id

        change_ticket(binding, ticket_public_id) if ticket_public_id.present?
        change_sticker(binding, tag_key) if tag_key.present?
        binding.save!

        Visits.refresh_locked!(event: event, tag_keys: [old_tag_key, binding.tag_key].uniq,
                               ticket_ids: [old_ticket_id, binding.ticket_id].compact.uniq)
        Visits.rebuild!(event: event)
      end
      binding
    end

    def dismiss_anomalies!(ids: nil)
      count = 0
      event.with_lock do
        count = event.rfid_observations.where(id: anomaly_ids(ids))
                     .update_all(dismissed_at: Time.current)
      end
      count
    end

    def delete_anomalies!(ids: nil)
      target = nil
      event.with_lock do
        target = anomaly_ids(ids, include_dismissed: true)
        remove_observations!(target)
        Visits.rebuild!(event: event)
      end
      target.length
    end

    private

    attr_reader :event

    # `ids: nil` means every anomaly; otherwise only ids that really are one.
    def anomaly_ids(ids, include_dismissed: false)
      all = Report.new(event).anomaly_observations(include_dismissed: include_dismissed).pluck(:id)
      return all if ids.nil?

      wanted = Array(ids).map(&:to_i)
      raise Error.new('Some readings are not anomalies of this event.') if (wanted - all).any?

      wanted
    end

    def visit_observation_ids(visit)
      ids = [visit.entry_observation_id, visit.exit_observation_id].compact
      return ids if visit.ticket_id.nil?

      span = event.rfid_observations.where(ticket_id: visit.ticket_id, outcome: 'accepted')
                  .where(captured_at: visit.entry_at..)
      span = span.where(captured_at: ..visit.exit_at) if visit.exit_at
      ids | span.pluck(:id)
    end

    # Readings can be referenced by visits and manual-exit corrections; clear
    # those first. A visit that only *exited* on a removed reading is kept and
    # reopened by the rebuild that follows.
    def remove_observations!(ids)
      return if ids.empty?

      event.rfid_visits.where(exit_observation_id: ids).update_all(exit_observation_id: nil)
      event.rfid_visits.where(entry_observation_id: ids).destroy_all
      event.rfid_corrections.where(entry_observation_id: ids).delete_all
      event.rfid_observations.where(id: ids).delete_all
    end

    def change_ticket(binding, public_id)
      ticket = event.tickets.find_by(public_id: public_id)
      raise Error.new('Ticket not found.', status: :not_found) if ticket.nil?
      raise Error.new('That ticket is cancelled.') if ticket.canceled?
      raise Error.new('That ticket is not paid.') unless ticket.paid?

      other = event.rfid_bindings.active.where(ticket_id: ticket.id).where.not(id: binding.id)
      raise Error.new('That ticket already has a sticker.', status: :conflict) if other.exists?

      binding.assign_attributes(ticket: ticket, ticket_public_id: ticket.public_id,
                                ticket_name: ticket.attendee_name)
    end

    # The typed value is the tag key shown in the panel. A station that reads
    # bytes reversed has a raw UID that is the key reversed; keep that relation.
    def change_sticker(binding, typed)
      key = Wire.normalize_uid(typed)
      raise Error.new('Sticker must be even-length hex.') if key.nil?

      other = event.rfid_bindings.active.where(tag_key: key).where.not(id: binding.id)
      raise Error.new('That sticker is linked to another ticket.', status: :conflict) if other.exists?

      reversed = binding.tag_key != Wire.normalize_uid(binding.uid_raw_hex)
      raw = reversed ? Wire.hex_upper(Wire.parse_hex(key).reverse) : key
      binding.assign_attributes(tag_key: key, uid_raw_hex: raw)
    end
  end
end
