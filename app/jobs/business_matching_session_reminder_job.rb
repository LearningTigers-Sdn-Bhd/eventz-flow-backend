# frozen_string_literal: true

# Sends participants reminders for their business matching sessions.
# Runs every 10 minutes via Sidekiq Cron. Supports:
# - 2 days before session (2_day, ~48 hours ahead)
# - 1 day before session (1_day, ~24 hours ahead)
# - 1 hour before session (1_hour, 50-70 minutes ahead)
#
# Dedupes via BusinessMatchingReminderLog so each booking receives at most
# one reminder per reminder type.
class BusinessMatchingSessionReminderJob < ApplicationJob
  queue_as :mailers

  REMINDER_WINDOWS = {
    '1_hour' => [50.minutes, 70.minutes],
    '1_day'  => [23.hours + 30.minutes, 24.hours + 30.minutes],
    '2_day'  => [47.hours + 30.minutes, 48.hours + 30.minutes]
  }.freeze

  def perform
    REMINDER_WINDOWS.each do |reminder_type, (window_start_offset, window_end_offset)|
      process_reminder_window(reminder_type, window_start_offset, window_end_offset)
    end
  end

  private

  def process_reminder_window(reminder_type, start_offset, end_offset)
    window_start = Time.current + start_offset
    window_end = Time.current + end_offset
    candidate_dates = [window_start.to_date, window_end.to_date].uniq

    BusinessMatchingBooking
      .where(booking_date: candidate_dates)
      .where.not(status: 'Cancelled')
      .includes(business_matching_session: :event)
      .find_each do |booking|
        start_at = _session_start_at(booking)
        next unless start_at && start_at.between?(window_start, window_end)
        next unless _reminder_enabled_for_event?(booking, reminder_type)
        next if _already_sent?(booking, reminder_type)

        _send_reminder(booking, reminder_type)
      end
  end

  def _session_start_at(booking)
    Time.zone.parse("#{booking.booking_date} #{booking.booking_time}")
  rescue ArgumentError, TypeError
    nil
  end

  def _reminder_enabled_for_event?(booking, reminder_type)
    event = booking.business_matching_session&.event
    return false unless event

    setting = event.event_email_setting
    return true unless setting # Default to enabled if no setting record exists yet

    return false unless setting.business_matching_reminder_enabled?
    return false if setting.email_enabled?('BookingMailer', 'session_reminder_email') == false

    case reminder_type
    when '2_day' then setting.business_matching_reminder_2_day?
    when '1_day' then setting.business_matching_reminder_1_day?
    when '1_hour' then setting.business_matching_reminder_1_hour?
    else true
    end
  end

  def _already_sent?(booking, reminder_type)
    BusinessMatchingReminderLog.exists?(
      business_matching_booking_id: booking.id,
      reminder_type: reminder_type
    )
  end

  def _send_reminder(booking, reminder_type)
    session = booking.business_matching_session
    return unless session

    transformed = BusinessMatchingService.new(nil).transform_bookings([booking], session).first.with_indifferent_access

    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'BookingMailer',
      mailer_action: 'session_reminder_email',
      args: [transformed, session.title, session.event_id, reminder_type],
      event: session.event,
      metadata: { event_id: session.event_id, booking_id: booking.id.to_s, reminder_type: reminder_type }
    )

    BusinessMatchingReminderLog.create!(
      business_matching_booking_id: booking.id,
      reminder_type: reminder_type,
      sent_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send #{reminder_type} session reminder for booking #{booking.id}: #{e.message}"
  end
end
