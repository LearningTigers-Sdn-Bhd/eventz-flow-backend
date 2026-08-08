# Sends each business matching host a single daily digest of that day's
# sessions (count, times, who they're meeting) instead of a per-session
# reminder — a host with many bookings in a day would otherwise get one
# email per session.
class BusinessMatchingHostDailyOverviewJob < ApplicationJob
  queue_as :mailers

  def perform
    today = Time.zone.today

    bookings = BusinessMatchingBooking
               .where(booking_date: today)
               .where.not(status: 'Cancelled')
               .where.not(host_user_id: nil)
               .includes(:host_user, business_matching_session: :event)

    bookings.group_by(&:host_user_id).each_value do |host_bookings|
      host = host_bookings.first.host_user
      next unless host&.email.present?

      _send_digest(host, host_bookings, today)
    end
  end

  private

  def _send_digest(host, bookings, date)
    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'BookingMailer',
      mailer_action: 'host_daily_overview_email',
      args: [host, bookings, date],
      related: host,
      dedupe: true,
      metadata: { host_user_id: host.id.to_s, date: date.to_s }
    )
  end
end
