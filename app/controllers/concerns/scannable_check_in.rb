# Shared helpers for the endpoints that record a scan.
# The scanning location is resolved server-side from the signed-in user's
# EventLocation assignment — a client-supplied location cannot gate anything.
module ScannableCheckIn
  extend ActiveSupport::Concern

  private

  def scan_location_for(event)
    return nil if current_user.blank?

    EventLocationMember
      .joins(:event_location)
      .find_by(member_id: current_user.id, event_locations: { event_id: event.id })
      &.event_location
  end

  def scan_blocked_payload(scan_log, message: 'Already scanned.')
    {
      error: message,
      checked_in_at: scan_log.scanned_at&.iso8601,
      blocked_by: {
        scanned_at: scan_log.scanned_at&.iso8601,
        location_name: scan_log.event_location&.name,
        scanned_by_name: scan_log.scanned_by&.full_name
      }
    }
  end
end
