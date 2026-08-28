# Single source of truth for "may this ticket/visitor be scanned right now?".
# Every check-in endpoint delegates here; none carries its own checked_in? guard.
class ScanGate
  # Returns :allowed, :unpaid, or the ScanLog row that blocks this scan.
  def self.call(scannable, at: Time.current, location: nil)
    new(scannable, at: at, location: location).call
  end

  # Records a scan if the gate allows it.
  # Returns [:ok, scan_log], [:unpaid, nil], or [:blocked, blocking_scan_log].
  def self.record!(scannable, by: nil, source: :staff_scan, location: nil, at: Time.current)
    scannable.with_lock do
      decision = call(scannable, at: at, location: location)
      next [:unpaid, nil] if decision == :unpaid
      next [:blocked, decision] unless decision == :allowed

      first_scan = ScanLog.for_scannable(scannable).none?

      log = ScanLog.create!(
        event: scannable.event,
        scannable: scannable,
        event_location: location,
        scanned_by_id: by&.id,
        scanned_at: at,
        source: source
      )

      if first_scan
        attrs = { checked_in: true, check_in_at: at, scanned_by_id: by&.id }
        attrs[:status] = :scanned if scannable.is_a?(Ticket)
        scannable.update!(attrs)
      end

      [:ok, log]
    end
  end

  # Removes the most recent scan and recomputes the denormalised columns.
  # Returns true if a row was removed, false if there were none.
  def self.undo!(scannable)
    scannable.with_lock do
      last = ScanLog.for_scannable(scannable).order(:scanned_at).last
      next false if last.nil?

      last.destroy!
      survivor = ScanLog.for_scannable(scannable).order(:scanned_at).first

      if survivor
        persist!(scannable, check_in_at: survivor.scanned_at, scanned_by_id: survivor.scanned_by_id)
      else
        attrs = { checked_in: false, check_in_at: nil, scanned_by_id: nil }
        attrs[:status] = :purchased if scannable.is_a?(Ticket)
        persist!(scannable, attrs)
      end

      true
    end
  end

  # save!(validate: false) rather than update!/update_columns: callbacks must
  # run (the ticket/visitor after_commit webhook that notifies external
  # systems — door displays, printers — of a check-in status change), but
  # validation must not, or unscanning a record with legacy invalid contact
  # data (pre-existing malformed email/phone) would raise instead of
  # succeeding — see spec/requests/v1/visitors_spec.rb's "legacy invalid
  # contact data" case.
  def self.persist!(scannable, attrs)
    scannable.assign_attributes(attrs)
    scannable.save!(validate: false)
  end
  private_class_method :persist!

  def initialize(scannable, at:, location:)
    @scannable = scannable
    @at = at
    @location = location
  end

  def call
    return :unpaid if unpaid_ticket?

    blocking_scan || :allowed
  end

  private

  attr_reader :scannable, :at, :location

  # Tickets with pending/failed/refunded payment must never be checked in.
  # Visitors have no payment_status, so this only applies to Ticket.
  def unpaid_ticket?
    scannable.is_a?(Ticket) && !scannable.paid?
  end

  def event
    scannable.event
  end

  def blocking_scan
    return earliest(scans) unless event.multiple_scans?

    case event.multiple_scan_mode
    when 'unlimited'    then nil
    when 'per_location' then earliest(scans_today.where(event_location_id: location&.id))
    when 'per_day'      then earliest(scans_today)
    end
  end

  def scans
    ScanLog.for_scannable(scannable)
  end

  def scans_today
    scans.on_date(at.in_time_zone.to_date)
  end

  def earliest(relation)
    relation.order(:scanned_at).first
  end
end
