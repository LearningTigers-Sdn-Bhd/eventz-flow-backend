# eventz_flow_api/app/mailers/booking_mailer.rb
class BookingMailer < ApplicationMailer
  default from: 'EventzFlow <notifications@updates.eventzflow.com>'

  def confirmation_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    Rails.logger.info "Sending confirmation email for event_id #{event_id}. Date: #{@booking_date}, Time: #{@booking_time}"

    mail(to: @booking['email'], subject: "Booking Confirmation for #{@event_title}")
  end

  def host_confirmation_email(booking_data, event_title, event_id, host)
    @booking = booking_data
    @event_title = event_title
    @host = host
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @host.email, subject: "New Booking: #{@booking['name']} for #{@event_title}")
  end

  def reschedule_email(booking_data, event_title, event_id, old_date, old_time)
    @booking = booking_data
    @event_title = event_title
    @old_date = old_date
    @old_time = old_time
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @booking['email'], subject: "Your Booking for #{@event_title} Has Been Rescheduled")
  end

  def host_reschedule_email(booking_data, event_title, event_id, host, old_date, old_time)
    @booking = booking_data
    @event_title = event_title
    @host = host
    @old_date = old_date
    @old_time = old_time
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @host.email, subject: "Booking Rescheduled: #{@booking['name']} for #{@event_title}")
  end

  def cancellation_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @booking['email'], subject: "Your Booking for #{@event_title} Has Been Cancelled")
  end

  def host_cancellation_email(booking_data, event_title, event_id, host)
    @booking = booking_data
    @event_title = event_title
    @host = host
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @host.email, subject: "Booking Cancelled: #{@booking['name']} for #{@event_title}")
  end

  def session_reminder_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(to: @booking['email'], subject: "Reminder: Your session for #{@event_title} starts in 1 hour")
  end

  def host_daily_overview_email(host, bookings, date)
    @host = host
    @date = date
    @session_count = bookings.size
    @event_groups = bookings.group_by { |b| b.business_matching_session.event }.map do |event, event_bookings|
      {
        event_title: event.title,
        dashboard_url: _dashboard_url(event.id),
        bookings: event_bookings
      }
    end

    session_word = @session_count == 1 ? "session" : "sessions"
    mail(to: @host.email, subject: "You have #{@session_count} #{session_word} today (#{date.strftime('%A, %B %d')})")
  end

  private

  def _assign_booking_datetime
    raw_date = @booking['booking_date'] || @booking['date']
    @booking_date = Date.parse(raw_date).strftime('%A, %B %d, %Y') rescue raw_date
    @booking_time = @booking['booking_time'] || @booking['time']
  end

  def _dashboard_url(event_id)
    base_url = ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
    "#{base_url}/event/#{event_id}/business-matching"
  end
end
