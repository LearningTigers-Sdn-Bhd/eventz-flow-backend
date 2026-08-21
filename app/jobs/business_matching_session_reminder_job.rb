# Sends participants a reminder ~1 hour before their business matching
# session. Runs every 10 minutes; looks 50-70 minutes ahead so a booking is
# never missed between two runs, and dedupes via BusinessMatchingReminderLog
# so a booking is never reminded twice even though that window overlaps
# across runs.
#
# Dedupe can't use EmailDelivery's built-in `related` dedupe (see
# EmailDelivery::AuditedDelivery) because business_matching_bookings has a
# uuid primary key while EmailDelivery#related_id is bigint — a uuid would
# silently mis-cast there.
class BusinessMatchingSessionReminderJob < ApplicationJob
  queue_as :mailers

  REMINDER_TYPE = "1_hour"
  WINDOW_START = 50.minutes
  WINDOW_END = 70.minutes

  def perform
    window_start = Time.current + WINDOW_START
    window_end = Time.current + WINDOW_END
    candidate_dates = [window_start.to_date, window_end.to_date].uniq

    BusinessMatchingBooking
      .where(booking_date: candidate_dates)
      .where.not(status: 'Cancelled')
      .includes(:business_matching_session)
      .find_each do |booking|
        start_at = _session_start_at(booking)
        next unless start_at && start_at.between?(window_start, window_end)
        next if _already_sent?(booking)

        _send_reminder(booking)
      end
  end

  private

  def _session_start_at(booking)
    Time.zone.parse("#{booking.booking_date} #{booking.booking_time}")
  rescue ArgumentError, TypeError
    nil
  end

  def _already_sent?(booking)
    BusinessMatchingReminderLog.exists?(business_matching_booking_id: booking.id, reminder_type: REMINDER_TYPE)
  end

  def _send_reminder(booking)
    session = booking.business_matching_session
    return unless session

    transformed = BusinessMatchingService.new(nil).transform_bookings([booking], session).first.with_indifferent_access

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'BookingMailer',
      mailer_action: 'session_reminder_email',
      args: [transformed, session.title, session.event_id],
      event: session.event,
      metadata: { event_id: session.event_id, booking_id: booking.id.to_s }
    )

    BusinessMatchingReminderLog.create!(
      business_matching_booking_id: booking.id,
      reminder_type: REMINDER_TYPE,
      sent_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send session reminder for booking #{booking.id}: #{e.message}"
  end
end
