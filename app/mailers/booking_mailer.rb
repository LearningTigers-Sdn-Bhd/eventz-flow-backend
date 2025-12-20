# eventz_flow_api/app/mailers/booking_mailer.rb
class BookingMailer < ApplicationMailer
  default from: 'no-reply@eventzflow.com' # Replace with your application's default sender email

  def confirmation_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    
    # Format dates for display in the email
    # Prefer booking_date/booking_time but fallback to date/time
    raw_date = @booking['booking_date'] || @booking['date']
    @booking_date = Date.parse(raw_date).strftime('%A, %B %d, %Y') rescue raw_date
    @booking_time = @booking['booking_time'] || @booking['time']

    Rails.logger.info "Sending confirmation email for event_id #{event_id}. Date: #{@booking_date}, Time: #{@booking_time}"

    mail(to: @booking['email'], subject: "Booking Confirmation for #{@event_title}")
  end
end
