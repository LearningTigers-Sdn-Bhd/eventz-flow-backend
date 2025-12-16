# app/services/business_matching_service.rb
require 'net/http'
require 'json'
require 'openssl'

class BusinessMatchingService < BaseService
  WEBHOOK_URL = "https://webhook.saleschatalyst.com/webhook/693921fb30946fd02504c059".freeze

  def fetch_events(event_id, force_refresh: false)
    cache_key = "business_matching_events_#{event_id}"
    pending_key = "business_matching_events_pending_#{event_id}" # Still useful for initial async request

    unless force_refresh
      cached_data = Rails.cache.read(cache_key)
      return BaseService::ServiceResult.new(success: true, data: cached_data) if cached_data.present?

      if Rails.cache.read(pending_key)
        Rails.logger.info "Fetch Events request pending, returning empty data."
        return BaseService::ServiceResult.new(success: true, data: [])
      end
    end

    payload = {
      action: "Fetch Events",
      event_id: event_id,
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Fetch Events): #{payload.inspect}"
    response = _send_request(payload)
    
    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        # Async response. Mark as pending to avoid loop and return empty array.
        Rails.cache.write(pending_key, true, expires_in: 2.minutes)
        Rails.logger.info "Fetch Events request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: [])
      elsif response.data.is_a?(Array)
         # Direct array response
         events = _transform_events(response.data, event_id)
         Rails.cache.write(cache_key, events, expires_in: 1.hour)
         Rails.cache.delete(pending_key) # Data received, no longer pending
         Rails.logger.info "Fetch Events synchronous response received and cached."
         return BaseService::ServiceResult.new(success: true, data: events)
      elsif response.data.is_a?(Hash) && (response.data["output"].is_a?(Array) || response.data["data"].is_a?(Array) || response.data["results"].is_a?(Array))
        # Synchronous response
        raw_events = response.data["output"] || response.data["data"] || response.data["results"]
        events = _transform_events(raw_events, event_id)
        Rails.cache.write(cache_key, events, expires_in: 1.hour)
        Rails.cache.delete(pending_key) # Data received, no longer pending
        Rails.logger.info "Fetch Events synchronous response received and cached."
        return BaseService::ServiceResult.new(success: true, data: events)
      else
        # Fallback or unexpected synchronous response
        Rails.logger.warn "Fetch Events: Unexpected data format from 3rd party for synchronous response."
        return BaseService::ServiceResult.new(success: true, data: [])
      end
    else
      response # Propagate error from _send_request
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_availability(bm_event_id, event_id)
    cache_key = "business_matching_availability_#{event_id}_#{bm_event_id}"
    cached_data = Rails.cache.read(cache_key)

    if cached_data.present?
      Rails.logger.info "Serving cached availability data for event #{event_id} (BM ID: #{bm_event_id})"
      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    # If not in cache, request from 3rd party (data will come asynchronously via receive)
    payload = {
      action: "Fetch Available Date",
      bm_event_id: bm_event_id,
      event_id: event_id,
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    response = _send_request(payload)

    if response.success?
      # If the 3rd party acknowledges the request, we return empty data and wait for callback
      # The callback will populate the cache.
      # We assume 'accepted: true' means "data will be sent via callback".
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Fetch Available Date request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { dates: [] })
      else
        # Process synchronous response if 3rd party sends it immediately
        raw_data = if response.data.is_a?(Hash)
                     response.data["output"] || response.data["data"] || response.data
                   else
                     response.data
                   end
        
        if raw_data.is_a?(Array)
            dates = raw_data.map do |item|
                {
                    day: item["day"],
                    date: item["date"],
                    slots: item["slots"].to_i
                }
            end
            Rails.cache.write(cache_key, { dates: dates }, expires_in: 1.hour) # Cache immediate response
            return BaseService::ServiceResult.new(success: true, data: { dates: dates })
        elsif raw_data.is_a?(Hash) && raw_data["dates"].is_a?(Array)
            dates = raw_data["dates"].map do |item|
                {
                    day: item["day"],
                    date: item["date"],
                    slots: item["slots"].to_i
                }
            end
            Rails.cache.write(cache_key, { dates: dates }, expires_in: 1.hour) # Cache immediate response
            return BaseService::ServiceResult.new(success: true, data: { dates: dates })
        elsif raw_data.is_a?(Hash) && raw_data["date"].is_a?(Array)
            dates = raw_data["date"].map do |item|
                {
                    day: item["day"],
                    date: item["date"],
                    slots: item["slots"].to_i
                }
            end
            Rails.cache.write(cache_key, { dates: dates }, expires_in: 1.hour) # Cache immediate response
            return BaseService::ServiceResult.new(success: true, data: { dates: dates })
        else
            Rails.logger.warn "Fetch Available Date: Unexpected data format from 3rd party for synchronous response."
            return BaseService::ServiceResult.new(success: true, data: { dates: [] })
        end
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_detailed_slots(bm_event_id, date, event_id)
    cache_key = "business_matching_detailed_slots_#{event_id}_#{bm_event_id}_#{date.parameterize}" # Use date in key
    cached_data = Rails.cache.read(cache_key)

    if cached_data.present?
      Rails.logger.info "Serving cached detailed slots data for event #{event_id} (BM ID: #{bm_event_id}) on #{date}"
      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    # If not in cache, request from 3rd party (data will come asynchronously via receive)
    payload = {
      action: "Fetch Available Slots",
      bm_event_id: bm_event_id,
      event_id: event_id,      
      date: date,
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Fetch Detailed Slots request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { slots: [] }) # Return empty array for async
      else
        raw_data = if response.data.is_a?(Hash)
                     response.data["output"] || response.data["data"] || response.data
                   else
                     response.data
                   end

        if raw_data.is_a?(Array)
          Rails.cache.write(cache_key, { slots: raw_data }, expires_in: 1.hour) # Cache immediate response
          return BaseService::ServiceResult.new(success: true, data: { slots: raw_data })
        elsif raw_data.is_a?(Hash) && raw_data["slots"].is_a?(Array)
          Rails.cache.write(cache_key, { slots: raw_data["slots"] }, expires_in: 1.hour) # Cache immediate response
          return BaseService::ServiceResult.new(success: true, data: { slots: raw_data["slots"] })
        else
          Rails.logger.warn "Fetch Detailed Slots: Unexpected data format from 3rd party for synchronous response."
          return BaseService::ServiceResult.new(success: true, data: { slots: [] })
        end
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_bookings(bm_event_id, event_id)
    cache_key = "business_matching_bookings_#{event_id}_#{bm_event_id}"
    cached_data = Rails.cache.read(cache_key)

    if cached_data.present?
      Rails.logger.info "Serving cached bookings data for event #{event_id} (BM ID: #{bm_event_id})"
      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    event = Event.find_by(id: event_id)
    year = event&.start_date&.year || Time.current.year

    payload = {
      action: "Search in Bookings",
      bm_event_id: bm_event_id,
      event_id: event_id,
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Search in Bookings request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { bookings: [] })
      else
        raw_data = if response.data.is_a?(Hash)
                     response.data["output"] || response.data["data"] || response.data
                   else
                     response.data
                   end

        if raw_data.is_a?(Array)
          bookings = _transform_bookings(raw_data, year)
          Rails.cache.write(cache_key, { bookings: bookings }, expires_in: 1.hour)
          return BaseService::ServiceResult.new(success: true, data: { bookings: bookings })
        elsif raw_data.is_a?(Hash) && raw_data["bookings"].is_a?(Array)
          bookings = _transform_bookings(raw_data["bookings"], year)
          Rails.cache.write(cache_key, { bookings: bookings }, expires_in: 1.hour)
          return BaseService::ServiceResult.new(success: true, data: { bookings: bookings })
        else
          Rails.logger.warn "Search in Bookings: Unexpected data format from 3rd party for synchronous response."
          return BaseService::ServiceResult.new(success: true, data: { bookings: [] })
        end
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def create_booking(bm_event_id, event_id, booking_params)
    payload = {
      action: "Create Booking",
      bm_event_id: bm_event_id,
      event_id: event_id,
      name: booking_params[:name],
      email: booking_params[:email],
      phone: booking_params[:phone],
      note: booking_params[:note],
      date: booking_params[:date],
      time: booking_params[:time],
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Create Booking): #{payload.inspect}"
    response = _send_request(payload)

    if response.success?
        if response.data.is_a?(Hash) && response.data["accepted"] == true
            Rails.logger.info "Create Booking request accepted, waiting for async callback."
            return BaseService::ServiceResult.new(success: true, data: { message: "Booking creation queued" })
        else
            Rails.logger.info "Create Booking synchronous response received."
            return BaseService::ServiceResult.new(success: true, data: response.data)
        end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def update_booking(bm_event_id, event_id, booking_id, booking_params)
    event = Event.find_by(id: event_id)
    year = event&.start_date&.year || Time.current.year
    
    date_param = booking_params[:booking_date]
    date_with_year = _format_date_with_year(date_param, year)

    payload = {
      action: "Update Booking",
      bm_event_id: bm_event_id,
      event_id: event_id,
      booking_id: booking_id,
      name: booking_params[:name],
      email: booking_params[:email],
      phone: booking_params[:phone],
      date: date_with_year,
      time: booking_params[:booking_time],
      status: booking_params[:status],
      payment_status: booking_params[:payment_status],
      detail1: booking_params[:attendance],
      detail2: booking_params[:host_comment],
      detail3: booking_params[:potential_deal_value],
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Update Booking): #{payload.inspect}"
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Update Booking request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { message: "Booking update queued" })
      else
        Rails.logger.info "Update Booking synchronous response received."
        return BaseService::ServiceResult.new(success: true, data: response.data)
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  private

  def _transform_events(raw_events, event_id)
    raw_events.map do |event_data|
      {
        id: event_data["id"] || event_data["_id"],
        event_id: event_id, # Use event_id instead of internal_event_id
        title: event_data["title"],
        duration: event_data["slotDuration"],
        location: event_data["locationLink"],
        admin_email: event_data["adminEmail"],
        admin_wa_number: event_data["adminWaNumber"]
      }
    end
  end

  def _transform_bookings(raw_bookings, year = Time.current.year)
    raw_bookings.map do |booking|
      {
        id: booking["_id"] || booking["id"],
        name: booking["name"],
        email: booking["email"],
        phone: booking["phone"],
        booking_date: _format_date_with_year(booking["bookingDate"], year),
        booking_time: booking["bookingTime"],
        duration: booking["bookingDuration"],
        status: booking["status"],
        event_title: booking["eventTitle"],
        location: booking["eventLocationLink"],
        cancel_link: booking["cancelBookingLink"],
        reschedule_link: booking["resheduleBookingLink"],
        meeting_approval_link: booking["meetingApprovalLink"],
        payment_status: booking["paymentStatus"],
        created_at: booking["createdAt"],
        attendance: booking["detail1"],
        host_comment: booking["detail2"],
        potential_deal_value: booking["detail3"]
      }
    end
  end

  def _format_date_with_year(date_str, year)
    return date_str if date_str.blank?
    return date_str if date_str.match?(/\d{4}/) # Already has year
    "#{date_str} #{year}"
  end

  def _send_request(payload)
    uri = URI.parse(WEBHOOK_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    # Bypass SSL verification to avoid "unable to get certificate CRL" error
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request.body = payload.to_json

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      parsed_body = JSON.parse(response.body)
      BaseService::ServiceResult.new(success: true, data: parsed_body)
    else
      BaseService::ServiceResult.new(success: false, errors: response.body, status: response.code.to_i)
    end
  rescue JSON::ParserError => e
    BaseService::ServiceResult.new(success: false, errors: "Failed to parse JSON response: #{e.message}", status: :bad_gateway)
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: "HTTP request failed: #{e.message}", status: :internal_server_error)
  end
end
