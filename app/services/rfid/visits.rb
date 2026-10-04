module Rfid
  # The visit projection.
  #
  # Visits are derived from accepted readings plus explicit staff corrections,
  # ordered by `(captured_at, station_id, delivery_id)` so any delivery order
  # gives the same rows. A rebuild never edits the readings themselves: the
  # current outcome/anomalies move, the saved `original_response` does not.
  #
  # Every method here expects the caller to already own the event lock (the
  # device services take it once per request).
  class Visits
    REPEATED_ENTRY = 'repeated_entry'
    UNMATCHED_EXIT = 'unmatched_exit'
    MANUAL_EXIT = 'manual_exit'
    MANUAL_ENTRY = 'manual_entry'

    # Re-measure the readings the given filters touch and rebuild the
    # projection once. Called after a binding, a check-in or a correction.
    def self.reconcile_locked!(event:, tag_key: nil, ticket_id: nil)
      refresh_locked!(event: event, tag_keys: [tag_key].compact, ticket_ids: [ticket_id].compact)
      rebuild!(event: event)
    end

    def self.refresh_locked!(event:, tag_keys: [], ticket_ids: [])
      return if tag_keys.empty? && ticket_ids.empty?

      scopes = []
      scopes << event.rfid_observations.where(tag_key: tag_keys) if tag_keys.any?
      scopes << event.rfid_observations.where(ticket_id: ticket_ids) if ticket_ids.any?
      scopes.reduce { |left, right| left.or(right) }.find_each do |observation|
        refresh(observation, event)
      end
    end

    # Only the readings a staff correction explicitly named.
    def self.refresh_ids_locked!(event:, observation_ids:)
      event.rfid_observations.where(id: observation_ids).find_each do |observation|
        refresh(observation, event)
      end
    end

    # Re-derive one reading's current meaning. Duplicate deliveries keep their
    # outcome: a duplicate is a fact about the delivery, not about the binding.
    def self.refresh(observation, event)
      return if observation.outcome == 'possible_duplicate'

      result = Adjudicate.call(event: event, observation: observation)
      return if observation.outcome == result.outcome &&
                observation.anomalies == result.anomalies &&
                observation.ticket_id == result.ticket_id

      observation.update_columns(outcome: result.outcome, anomalies: result.anomalies,
                                 ticket_id: result.ticket_id)
    end

    # Rebuilds from readings as currently adjudicated. It does not re-measure
    # them (one Adjudicate per reading, under the event lock, on every batch):
    # whoever changes what readings mean calls refresh_* first.
    def self.rebuild!(event:)
      readings = event.rfid_observations.where(outcome: 'accepted')
                      .order(:captured_at, :station_id, :delivery_id).to_a
      role_overrides = event.rfid_corrections.where(kind: 'station_change').order(:id)
                            .each_with_object({}) do |correction, roles|
        next unless correction.details['role'].present?

        Array(correction.details['observation_ids']).each do |id|
          roles[id.to_i] = [correction.station_id, correction.details['role']]
        end
      end
      readings.each do |reading|
        station_id, role = role_overrides[reading.id]
        reading.role = role if station_id == reading.station_id
      end
      manual_entries = event.rfid_corrections.where(kind: MANUAL_ENTRY).order(:id).group_by(&:ticket_id)
      by_ticket = readings.group_by(&:ticket_id)
      tickets = event.tickets.where(id: by_ticket.keys | manual_entries.keys).index_by(&:id)
      corrections = event.rfid_corrections.order(:id).group_by(&:entry_observation_id)

      desired = {}
      visit_anomalies = Hash.new { |hash, key| hash[key] = [] }

      (by_ticket.keys | manual_entries.keys).each do |ticket_id|
        project(by_ticket.fetch(ticket_id, []), manual_entries.fetch(ticket_id, []), ticket_id,
                tickets, corrections, desired, visit_anomalies)
      end

      persist!(event, desired, visit_anomalies, readings)
    end

    # What a staff "manual entry" looks like to the timeline: an entry at a
    # chosen time. Left open it is closed by the guest's next real exit, like
    # any other entry; given an exit time it closes itself.
    ManualStart = Struct.new(:id, :captured_at, :role, keyword_init: true)

    # One ticket's timeline: reads in capture order, with manual corrections
    # inserted where they happened, so a correction really ends that visit.
    def self.project(group, manual_entries, ticket_id, tickets, corrections, desired, visit_anomalies)
      events = group.map { |reading| [reading.captured_at, 0, reading] }
      group.each do |reading|
        (corrections[reading.id] || []).each do |correction|
          events << [correction.exit_at, 1, correction]
        end
      end
      manual_entries.each do |correction|
        events << [correction.entry_at, 0, ManualStart.new(id: correction.id, captured_at: correction.entry_at,
                                                          role: 'entry')]
        events << [correction.exit_at, 1, correction] if correction.exit_at
      end

      ticket = tickets[ticket_id]
      open = nil
      events.sort_by { |time, rank, row| [time, rank, row.is_a?(ManualStart) ? 0 : 1, row.id] }
            .each do |_time, rank, row|
        if rank == 1
          next unless open && closes?(open, row)

          open[:exit_observation_id] = nil
          open[:exit_at] = row.exit_at
          unless row.kind == MANUAL_ENTRY
            open[:manual] = true
            open[:anomalies] = [MANUAL_EXIT]
          end
          open = nil
          next
        end

        manual_start = row.is_a?(ManualStart)
        if row.role == 'entry'
          if open.nil?
            open = { entry_observation_id: manual_start ? nil : row.id,
                     correction_id: manual_start ? row.id : nil, entry_at: row.captured_at,
                     ticket_id: ticket_id, ticket_public_id: ticket&.public_id,
                     ticket_name: ticket&.attendee_name, exit_observation_id: nil,
                     exit_at: nil, manual: false, anomalies: manual_start ? [MANUAL_ENTRY] : [] }
            desired[manual_start ? "m#{row.id}" : row.id] = open
          elsif !manual_start
            visit_anomalies[row.id] << REPEATED_ENTRY
          end
        elsif open
          open[:exit_observation_id] = row.id
          open[:exit_at] = row.captured_at
          open = nil
        else
          visit_anomalies[row.id] << UNMATCHED_EXIT
        end
      end
    end

    def self.closes?(open, correction)
      if correction.kind == MANUAL_ENTRY
        open[:correction_id] == correction.id
      else
        open[:entry_observation_id] == correction.entry_observation_id
      end
    end
    private_class_method :closes?
    private_class_method :project

    def self.persist!(event, desired, visit_anomalies, readings)
      existing = event.rfid_visits.index_by { |visit| visit.correction_id ? "m#{visit.correction_id}" : visit.entry_observation_id }
      desired.each do |entry_observation_id, attributes|
        visit = existing.delete(entry_observation_id)
        visit ? visit.update!(attributes) : event.rfid_visits.create!(attributes)
      end
      existing.each_value(&:destroy!)

      by_id = readings.index_by(&:id)
      visit_anomalies.each do |observation_id, extra|
        reading = by_id[observation_id]
        next if reading.nil?

        merged = (reading.anomalies + extra).uniq
        reading.update_columns(anomalies: merged) if merged != reading.anomalies
      end
    end
    private_class_method :persist!
  end
end
