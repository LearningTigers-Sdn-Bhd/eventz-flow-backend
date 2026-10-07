# frozen_string_literal: true

# eventz_flow_api/app/mailers/booking_mailer.rb
class BookingMailer < ApplicationMailer
  default from: 'EventzFlow <notifications@updates.eventzflow.com>'

  def confirmation_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    _assign_booking_links(event_id)
    @dashboard_url = _dashboard_url(event_id)

    Rails.logger.info "Sending confirmation email for event_id #{event_id}. Date: #{@booking_date}, Time: #{@booking_time}"

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Booking Confirmation for #{@event_title}"
    )
  end

  # Sent instead of confirmation_email when the event requires approval — the
  # booking exists but nothing is confirmed yet.
  def pending_approval_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    _assign_booking_links(event_id)
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Booking Request Received for #{@event_title} — Awaiting Approval"
    )
  end

  # Sent once a host/admin approves a previously pending booking.
  def approval_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    _assign_booking_links(event_id)
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Your Booking for #{@event_title} Is Confirmed"
    )
  end

  def host_confirmation_email(booking_data, event_title, event_id, host)
    @booking = booking_data
    @event_title = event_title
    @host = host
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    subject = if @booking['status'] == 'Pending'
                "Approval Needed: #{@booking['name']} requested a session for #{@event_title}"
              else
                "New Booking: #{@booking['name']} for #{@event_title}"
              end

    mail(
      to: @host.email,
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: subject
    )
  end

  def reschedule_email(booking_data, event_title, event_id, old_date, old_time)
    @booking = booking_data
    @event_title = event_title
    @old_date = old_date
    @old_time = old_time
    _assign_booking_datetime
    _assign_booking_links(event_id)
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Your Booking for #{@event_title} Has Been Rescheduled"
    )
  end

  def host_reschedule_email(booking_data, event_title, event_id, host, old_date, old_time)
    @booking = booking_data
    @event_title = event_title
    @host = host
    @old_date = old_date
    @old_time = old_time
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @host.email,
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Booking Rescheduled: #{@booking['name']} for #{@event_title}"
    )
  end

  def cancellation_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Your Booking for #{@event_title} Has Been Cancelled"
    )
  end

  def host_cancellation_email(booking_data, event_title, event_id, host)
    @booking = booking_data
    @event_title = event_title
    @host = host
    _assign_booking_datetime
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @host.email,
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Booking Cancelled: #{@booking['name']} for #{@event_title}"
    )
  end

  def session_reminder_email(booking_data, event_title, event_id)
    @booking = booking_data
    @event_title = event_title
    _assign_booking_datetime
    _assign_booking_links(event_id)
    @dashboard_url = _dashboard_url(event_id)

    mail(
      to: @booking['email'],
      from: _bm_sender_from(event_id),
      reply_to: _bm_reply_to(event_id),
      subject: "Reminder: Your session for #{@event_title} starts in 1 hour"
    )
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
    event = bookings.first&.business_matching_session&.event
    mail(
      to: @host.email,
      from: _bm_sender_from(event),
      reply_to: _bm_reply_to(event),
      subject: "You have #{@session_count} #{session_word} today (#{date.strftime('%A, %B %d')})"
    )
  end

  def host_invitation_email(recipient_email, event_or_id_or_title, session_title, invite_url, inviter_name, custom_message = nil)
    event = _resolve_event(event_or_id_or_title)
    @event_title = event&.title.presence || event_or_id_or_title.to_s
    @session_title = session_title
    @invite_url = invite_url
    @inviter_name = inviter_name
    @sender_display_name = _bm_sender_display_name(event)

    email_setting = event&.event_email_setting
    @host_label = email_setting&.business_matching_host_label.presence || 'Business Host'

    raw_message = custom_message.presence || email_setting&.business_matching_host_invite_message.presence
    if raw_message.present?
      @custom_message = raw_message
                        .gsub('{{event_name}}', @event_title.to_s)
                        .gsub('{{session_title}}', @session_title.to_s)
                        .gsub('{{inviter_name}}', @inviter_name.presence || 'The event organizer')
                        .gsub('{{host_label}}', @host_label.to_s)
                        .gsub('{{invite_url}}', @invite_url.to_s)
    end

    raw_subject = email_setting&.business_matching_host_invite_subject.presence ||
                  "You've been invited as a #{@host_label} for #{@event_title}"
    subject_text = raw_subject
                   .gsub('{{event_name}}', @event_title.to_s)
                   .gsub('{{session_title}}', @session_title.to_s)
                   .gsub('{{inviter_name}}', @inviter_name.presence || 'The event organizer')
                   .gsub('{{host_label}}', @host_label.to_s)

    mail(
      to: recipient_email,
      from: _bm_sender_from(event),
      reply_to: _bm_reply_to(event),
      subject: subject_text
    )
  end

  private

  def _resolve_event(event_or_id_or_title)
    if event_or_id_or_title.is_a?(Event)
      event_or_id_or_title
    elsif event_or_id_or_title.is_a?(Integer) || event_or_id_or_title.to_s.match?(/\A\d+\z/)
      Event.find_by(id: event_or_id_or_title)
    else
      Event.find_by(title: event_or_id_or_title)
    end
  end

  def _bm_sender_from(event_or_id)
    event = event_or_id.is_a?(Event) ? event_or_id : Event.find_by(id: event_or_id)
    email_setting = event&.event_email_setting
    name = email_setting&.business_matching_sender_name.presence ||
           email_setting&.sender_name.presence ||
           event&.title.presence ||
           'EventzFlow'
    address = email_setting&.sender_address.presence || 'notifications@updates.eventzflow.com'
    format_sender(name, address)
  end

  def _bm_reply_to(event_or_id)
    event = event_or_id.is_a?(Event) ? event_or_id : Event.find_by(id: event_or_id)
    event&.event_email_setting&.contact_email.presence
  end

  def _bm_sender_display_name(event_or_id)
    event = event_or_id.is_a?(Event) ? event_or_id : Event.find_by(id: event_or_id)
    email_setting = event&.event_email_setting
    email_setting&.business_matching_sender_name.presence ||
      email_setting&.sender_name.presence ||
      event&.title.presence ||
      'EventzFlow'
  end

  def _assign_booking_datetime
    raw_date = @booking['booking_date'] || @booking['date']
    @booking_date = Date.parse(raw_date).strftime('%A, %B %d, %Y') rescue raw_date
    @booking_time = @booking['booking_time'] || @booking['time']
  end

  def _frontend_base_url
    ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
  end

  def _dashboard_url(event_id)
    "#{_frontend_base_url}/event/#{event_id}/business-matching"
  end

  def _assign_booking_links(event_id)
    booking_id = @booking['id']
    resched_path = @booking['reschedule_link'].presence || "/event/#{event_id}/booking/#{booking_id}/reschedule"
    cancel_path = @booking['cancel_link'].presence || "/event/#{event_id}/booking/#{booking_id}/cancel"
    @reschedule_url = "#{_frontend_base_url}#{resched_path}"
    @cancel_url = "#{_frontend_base_url}#{cancel_path}"
  end
end
