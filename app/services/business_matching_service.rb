# app/services/business_matching_service.rb
require 'net/http'
require 'json'
require 'openssl'

class BusinessMatchingService < BaseService
  WEBHOOK_URL = "https://webhook.saleschatalyst.com/webhook/693921fb30946fd02504c059".freeze

  def fetch_events(event_id, force_refresh: false)
    cache_key = "business_matching_events_#{event_id}"
    raw_cache_key = "business_matching_events_raw_#{event_id}"
    pending_key = "business_matching_events_pending_#{event_id}" # Still useful for initial async request

    if force_refresh
      Rails.logger.info "Force refresh requested. Clearing all business matching cache for event #{event_id}"
      # Use Regex for delete_matched as string is interpreted as Regex in MemoryStore/Redis
      Rails.cache.delete_matched(/business_matching_.*_#{event_id}.*/)
    end

    unless force_refresh
      cached_data = Rails.cache.read(cache_key)
      return BaseService::ServiceResult.new(success: true, data: cached_data) if cached_data.present?

      # Try to reconstruct from RAW cache if available (avoids hitting external API just for local host updates)
      raw_data = Rails.cache.read(raw_cache_key)
      if raw_data.present?
        Rails.logger.info "Re-transforming events from RAW cache for event #{event_id}"
        events = _transform_events(raw_data, event_id)
        Rails.cache.write(cache_key, events, expires_in: 1.hour)
        return BaseService::ServiceResult.new(success: true, data: events)
      end

      if Rails.cache.read(pending_key)
        Rails.logger.info "Fetch Events request pending, returning empty data."
        return BaseService::ServiceResult.new(success: true, data: [])
      end
    end

    payload = {
      action: "Fetch Events",
      event_id: event_id,
      user_email: user&.email,
      user_name: user&.full_name,
      user_id: user&.id
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
         raw_events = response.data
         Rails.cache.write(raw_cache_key, raw_events, expires_in: 1.hour) # Cache RAW data

         events = _transform_events(raw_events, event_id)
         Rails.cache.write(cache_key, events, expires_in: 1.hour)
         Rails.cache.delete(pending_key) # Data received, no longer pending
         Rails.logger.info "Fetch Events synchronous response received and cached."
         return BaseService::ServiceResult.new(success: true, data: events)
      elsif response.data.is_a?(Hash) && (response.data["output"].is_a?(Array) || response.data["data"].is_a?(Array) || response.data["results"].is_a?(Array))
        # Synchronous response
        raw_events = response.data["output"] || response.data["data"] || response.data["results"]
        Rails.cache.write(raw_cache_key, raw_events, expires_in: 1.hour) # Cache RAW data

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

  def fetch_availability(bm_event_id, event_id, force_refresh: false)
    # This method is for general event availability, not host-specific.
    # The new fetch_host_availability will handle host-specific requests.
    cache_key = "business_matching_availability_#{event_id}_#{bm_event_id}"
    
    Rails.cache.delete(cache_key) if force_refresh

    cached_data = Rails.cache.read(cache_key)

    if !force_refresh && cached_data.present?
      Rails.logger.info "Serving cached availability data for event #{event_id} (BM ID: #{bm_event_id})"
      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    payload = {
      action: "Fetch Available Date",
      bm_event_id: bm_event_id,
      event_id: event_id,
      user_email: user&.email,
      user_name: user&.full_name,
      user_id: user&.id
    }
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Fetch Available Date request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { dates: [] })
      else
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

  def fetch_host_availability(event_id, host_user_id, force_refresh: false)
    # The external system uses event_id and host_user_id to fetch host-specific availability.
    
    cache_key = "business_matching_host_availability_#{event_id}_#{host_user_id}"
    
    Rails.cache.delete(cache_key) if force_refresh

    cached_data = Rails.cache.read(cache_key)

    if !force_refresh && cached_data.present?
      Rails.logger.info "Serving cached host availability data for event #{event_id} (Host ID: #{host_user_id})"
      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    payload = {
      action: "Fetch Host Available Date", # New action for the webhook
      event_id: event_id,
      host_user_id: host_user_id, # Pass the host's user ID
      user_email: user.email, # Current user making the request
      user_name: user.full_name,
      user_id: user.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Fetch Host Availability): #{payload.inspect}"
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Fetch Host Available Date request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { dates: [] })
      else
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
            Rails.logger.warn "Fetch Host Available Date: Unexpected data format from 3rd party for synchronous response."
            return BaseService::ServiceResult.new(success: true, data: { dates: [] })
        end
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_detailed_slots(bm_event_id, date, event_id, force_refresh: false)
    cache_key = "business_matching_detailed_slots_#{event_id}_#{bm_event_id}_#{date.parameterize}" # Use date in key
    Rails.logger.info "DEBUG: fetch_detailed_slots key: #{cache_key}"
    
    Rails.cache.delete(cache_key) if force_refresh

    cached_data = Rails.cache.read(cache_key)

    if !force_refresh && cached_data.present?
      Rails.logger.info "Serving cached detailed slots data for event #{event_id} (BM ID: #{bm_event_id}) on #{date}"
      
      # Perform post-cache filtering based on bookings to ensure accuracy
      # This handles cases where the cache is stale or external API is slow to update
      slots = cached_data[:slots]
      
      # Fetch bookings for this day to exclude taken slots
      # We use a short cache or direct fetch for bookings to be safe
      bookings_result = fetch_bookings(bm_event_id, event_id, force_refresh: force_refresh)
      
      if bookings_result.success? && bookings_result.data[:bookings].present?
         bookings = bookings_result.data[:bookings]
         # date format from fetch_detailed_slots is "d MMMM yyyy" (e.g. 20 December 2025)
         # bookings have "date" field, need to normalize.
         
         booked_times = bookings.select do |b| 
           # Normalize booking date to match requested date
           # Booking date might be "2025-12-20" or "20 December 2025"
           b_date = b[:date] || b[:booking_date]
           
           begin
             parsed_b_date = Date.parse(b_date).strftime("%-d %B %Y")
             parsed_req_date = Date.parse(date).strftime("%-d %B %Y")
             parsed_b_date == parsed_req_date
           rescue
             false
           end
         end.map { |b| b[:time] || b[:booking_time] }
         
         Rails.logger.info "DEBUG: filtering slots. Booked times for #{date}: #{booked_times}"
         
         if booked_times.any?
           filtered_slots = slots.reject { |s| booked_times.include?(s["slot"] || s[:slot]) }
           return BaseService::ServiceResult.new(success: true, data: { slots: filtered_slots })
         end
      end

      return BaseService::ServiceResult.new(success: true, data: cached_data)
    end

    # If not in cache, request from 3rd party (data will come asynchronously via receive)
    payload = {
      action: "Fetch Available Slots",
      bm_event_id: bm_event_id,
      event_id: event_id,      
      date: date,
      user_email: user&.email,
      user_name: user&.full_name,
      user_id: user&.id
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
          final_slots = raw_data
          
          # Initial Filter on fresh data
          bookings_result = fetch_bookings(bm_event_id, event_id)
          if bookings_result.success? && bookings_result.data[:bookings].present?
             bookings = bookings_result.data[:bookings]
             booked_times = bookings.select do |b| 
               b_date = b[:date] || b[:booking_date]
               begin
                 Date.parse(b_date).strftime("%-d %B %Y") == Date.parse(date).strftime("%-d %B %Y")
               rescue
                 false
               end
             end.map { |b| b[:time] || b[:booking_time] }
             
             if booked_times.any?
               final_slots = raw_data.reject { |s| booked_times.include?(s["slot"] || s[:slot]) }
             end
          end
          
          # Cache the RAW slots, not the filtered ones, so we can re-filter later if bookings change?
          # Actually, safer to cache the raw from API and filter on read.
          # But for now, let's cache the result. 
          # Wait, if we cache filtered result, and a booking is cancelled, we might hide a slot.
          # Better to cache raw_data and filter in the "cached_data" block above?
          # Yes. But here we must return filtered data.
          
          Rails.cache.write(cache_key, { slots: raw_data }, expires_in: 1.hour) # Cache RAW response
          return BaseService::ServiceResult.new(success: true, data: { slots: final_slots })
          
        elsif raw_data.is_a?(Hash) && raw_data["slots"].is_a?(Array)
          final_slots = raw_data["slots"]
          
           # Initial Filter on fresh data
          bookings_result = fetch_bookings(bm_event_id, event_id)
          if bookings_result.success? && bookings_result.data[:bookings].present?
             bookings = bookings_result.data[:bookings]
             booked_times = bookings.select do |b| 
               b_date = b[:date] || b[:booking_date]
               begin
                 Date.parse(b_date).strftime("%-d %B %Y") == Date.parse(date).strftime("%-d %B %Y")
               rescue
                 false
               end
             end.map { |b| b[:time] || b[:booking_time] }
             
             if booked_times.any?
               final_slots = raw_data["slots"].reject { |s| booked_times.include?(s["slot"] || s[:slot]) }
             end
          end

          Rails.cache.write(cache_key, { slots: raw_data["slots"] }, expires_in: 1.hour) # Cache RAW response
          return BaseService::ServiceResult.new(success: true, data: { slots: final_slots })
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

  def fetch_bookings(bm_event_id, event_id, force_refresh: false)
    cache_key = "business_matching_bookings_#{event_id}_#{bm_event_id}"
    
    Rails.cache.delete(cache_key) if force_refresh

    cached_data = Rails.cache.read(cache_key)

    if !force_refresh && cached_data.present?
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
                
                if force_refresh # Only wait if force_refresh is true (for reports)
                    Rails.logger.info "FORCE REFRESH: Polling cache for bookings data for BM ID: #{bm_event_id}"
                    max_attempts = 60 # Check for 60 seconds
                    attempts = 0
                    
                    loop do
                        cached_data = Rails.cache.read(cache_key) # Check for data in cache
                        if cached_data.present? && cached_data[:bookings].present?
                            Rails.logger.info "FORCE REFRESH: Bookings data found in cache."
                            return BaseService::ServiceResult.new(success: true, data: cached_data)
                        end
                        
                        attempts += 1
                        break if attempts >= max_attempts
                        sleep 1 # Wait 1 second before next attempt
                    end
                    Rails.logger.warn "FORCE REFRESH: Bookings data not found in cache after timeout for BM ID: #{bm_event_id}. Returning empty list to avoid blocking report."
                    return BaseService::ServiceResult.new(success: true, data: { bookings: [] })
                else
                    return BaseService::ServiceResult.new(success: true, data: { bookings: [] }) # For normal async flow
                end
            elsif response.data.is_a?(Hash) && (response.data["output"] || response.data["data"])
                # Synchronous response
                raw_data = response.data["output"] || response.data["data"]
                
                bookings_to_process = []
                if raw_data.is_a?(Array)
                  bookings_to_process = raw_data
                elsif raw_data.is_a?(Hash) && raw_data["bookings"].is_a?(Array)
                  bookings_to_process = raw_data["bookings"]
                end
    
                # Filter bookings if the user is a business host for this event
                event = Event.find_by(id: event_id) # Need event object to check roles
                if event.present? && user&.is_business_host?(event) && !user&.is_org_owner_or_organizer?
                  Rails.logger.info "Filtering bookings for business host #{user.id} in event #{event_id}"
                  bookings_to_process = bookings_to_process.select do |booking|
                    booking["host_user_id"].to_s == user.id.to_s
                  end
                end
    
                if bookings_to_process.any?
                  bookings = _transform_bookings(bookings_to_process, year)
                  Rails.cache.write(cache_key, { bookings: bookings }, expires_in: 1.hour)
                  return BaseService::ServiceResult.new(success: true, data: { bookings: bookings })
                else
                  Rails.logger.warn "Search in Bookings: Unexpected data format from 3rd party or no bookings after host filter."
                  return BaseService::ServiceResult.new(success: true, data: { bookings: [] })
                end
            else
                Rails.logger.info "Search in Bookings synchronous response received."
                return BaseService::ServiceResult.new(success: true, data: response.data)
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

  def public_create_booking(bm_event_id, event_id, host_user_id, booking_params)
    payload = {
      action: "Public Create Booking", # A new action for the webhook
      bm_event_id: bm_event_id,
      event_id: event_id,
      host_user_id: host_user_id, # The host for whom the booking is made
      name: booking_params[:name],
      email: booking_params[:email],
      phone: booking_params[:phone],
      date: booking_params[:date],
      time: booking_params[:time],
      user_email: user&.email, # The user creating the booking
      user_name: user&.full_name,
      user_id: user&.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Public Create Booking): #{payload.inspect}"
    response = _send_request(payload)

    if response.success?
        if response.data.is_a?(Hash) && response.data["accepted"] == true
            Rails.logger.info "Public Create Booking request accepted, but processing synchronously to send email and confirm UI."
            
            main_event = Event.find_by(id: event_id)
            main_event_title = main_event&.title || "Event"
            
            # Attempt to fetch details (title, location) from BM event
            bm_event_title = main_event_title # Fallback
            location = "To be confirmed"
            
            begin
                events_result = fetch_events(event_id)
                if events_result.success? && events_result.data.is_a?(Array)
                    target_bm_event = events_result.data.find { |e| e[:id].to_s == bm_event_id.to_s }
                    if target_bm_event
                        location = target_bm_event[:location] if target_bm_event[:location].present?
                        bm_event_title = target_bm_event[:title] if target_bm_event[:title].present?
                    end
                end
            rescue => e
                Rails.logger.warn "Failed to fetch BM details for temp booking: #{e.message}"
            end

            temp_booking_data = {
              name: booking_params[:name],
              email: booking_params[:email],
              phone: booking_params[:phone],
              booking_date: booking_params[:date], # Added for frontend compatibility
              booking_time: booking_params[:time], # Added for frontend compatibility
              event_title: bm_event_title, # Use BM session title
              location: location,
              cancel_link: "", # Default value
              reschedule_link: "", # Default value
              meeting_approval_link: "", # Default value
              payment_status: "Pending", # Default value
              created_at: Time.current.iso8601,
              host_comment: "", # Default value
              potential_deal_value: "", # Default value
              attendance: "" # Default value
            }.with_indifferent_access
            
            temp_booking_data[:id] = "Pending-#{SecureRandom.hex(4)}"
            
            Rails.logger.info "TEMP DATA DEBUG: #{temp_booking_data.inspect}"
            Rails.logger.info "DEBUG: ENTERING OPTIMISTIC UPDATE BLOCK"

            # Send email immediately
            EmailDelivery::AuditedDelivery.deliver_now(
              mailer_name: 'BookingMailer',
              mailer_action: 'confirmation_email',
              args: [temp_booking_data, bm_event_title, event_id],
              related: nil,
              metadata: { event_id: event_id, booking_id: temp_booking_data[:id] }
            )

            # Cache the provisional data for a short period
            Rails.cache.write("pending_booking_#{temp_booking_data[:id]}", temp_booking_data, expires_in: 5.minutes)

            # Invalidate availability caches so subsequent requests get fresh data
            Rails.cache.delete("business_matching_availability_#{event_id}_#{bm_event_id}")
            
            # Optimistically update the slots cache to remove the booked time immediately
            booked_date_param = booking_params[:date]
            booked_time_param = booking_params[:time]
            
            Rails.logger.info "DEBUG: Optimistic Update - Date: #{booked_date_param}, Time: #{booked_time_param}"

            if booked_date_param.present? && booked_time_param.present?
                 begin
                   parsed_date = Date.parse(booked_date_param)
                   formatted_date_key = parsed_date.strftime("%-d %B %Y")
                   slots_cache_key = "business_matching_detailed_slots_#{event_id}_#{bm_event_id}_#{formatted_date_key.parameterize}"
                   
                   Rails.logger.info "DEBUG: Optimistic Update - Key: #{slots_cache_key}"

                   cached_slots = Rails.cache.read(slots_cache_key)
                   Rails.logger.info "DEBUG: Optimistic Update - Cached Slots Found: #{cached_slots.present?}"

                   if cached_slots.is_a?(Hash) && cached_slots[:slots].is_a?(Array)
                     # Filter out the booked slot
                     updated_slots = cached_slots[:slots].reject { |s| s["slot"] == booked_time_param || s[:slot] == booked_time_param }
                     # Update the cache
                     Rails.cache.write(slots_cache_key, { slots: updated_slots }, expires_in: 1.hour)
                     Rails.logger.info "DEBUG: Optimistic Update - Written new slots. Count: #{updated_slots.size}"
                   end
                 rescue => e
                   Rails.logger.warn "Failed to optimistically update slots cache: #{e.message}"
                 end
            end

            # Return provisional booking data to frontend
            return BaseService::ServiceResult.new(success: true, data: temp_booking_data)
        elsif response.data.is_a?(Hash) && (response.data["output"] || response.data["data"])
            # The booking details should be in 'output' or 'data' field
            raw_data = response.data["output"] || response.data["data"]
            
            # Handle nested booking object if present
            booking_data = if raw_data["booking"].is_a?(Hash)
                             raw_data["booking"]
                           else
                             raw_data
                           end

            # Fetch the main event for its title
            main_event = Event.find_by(id: event_id)
            event_title = main_event&.title || "Event" # Fallback title
            year = main_event&.start_date&.year || Time.current.year

            # Transform raw booking data to standardized format
            transformed_booking = _transform_bookings([booking_data], year).first

            # Ensure booking_data has necessary fields for mailer, add if missing from external API
            final_booking_data = transformed_booking.merge(booking_params.slice(:name, :email, :phone).with_indifferent_access)
            final_booking_data['id'] ||= booking_data['_id'] || "N/A"

            # Send confirmation email
            EmailDelivery::AuditedDelivery.deliver_later(
              mailer_name: 'BookingMailer',
              mailer_action: 'confirmation_email',
              args: [final_booking_data, event_title, event_id],
              related: nil,
              metadata: { event_id: event_id, booking_id: final_booking_data['id'] }
            )

            # Invalidate availability caches
            Rails.cache.delete("business_matching_availability_#{event_id}_#{bm_event_id}")
            
            # Optimistically update the slots cache
            booked_date_param = booking_params[:date]
            booked_time_param = booking_params[:time]
            
            Rails.logger.info "DEBUG: Optimistic Update (Sync) - Date: #{booked_date_param}, Time: #{booked_time_param}"

            if booked_date_param.present? && booked_time_param.present?
                 begin
                   parsed_date = Date.parse(booked_date_param)
                   formatted_date_key = parsed_date.strftime("%-d %B %Y")
                   slots_cache_key = "business_matching_detailed_slots_#{event_id}_#{bm_event_id}_#{formatted_date_key.parameterize}"
                   
                   Rails.logger.info "DEBUG: Optimistic Update (Sync) - Key: #{slots_cache_key}"

                   cached_slots = Rails.cache.read(slots_cache_key)
                   Rails.logger.info "DEBUG: Optimistic Update (Sync) - Cached Slots Found: #{cached_slots.present?}"

                   if cached_slots.is_a?(Hash) && cached_slots[:slots].is_a?(Array)
                     updated_slots = cached_slots[:slots].reject { |s| s["slot"] == booked_time_param || s[:slot] == booked_time_param }
                     Rails.cache.write(slots_cache_key, { slots: updated_slots }, expires_in: 1.hour)
                     Rails.logger.info "DEBUG: Optimistic Update (Sync) - Written new slots. Count: #{updated_slots.size}"
                   end
                 rescue => e
                   Rails.logger.warn "Failed to optimistically update slots cache: #{e.message}"
                 end
            end

            return BaseService::ServiceResult.new(success: true, data: transformed_booking)
        else
            Rails.logger.info "Public Create Booking synchronous response received."
            return BaseService::ServiceResult.new(success: true, data: response.data)
        end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def update_booking(bm_event_id, event_id, booking_id, booking_params, host_user_id: nil)
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
    payload[:host_user_id] = host_user_id if host_user_id.present?
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

  def fetch_single_booking(bm_event_id, event_id, booking_id)
    event = Event.find_by(id: event_id)
    year = event&.start_date&.year || Time.current.year

    payload = {
      action: "Fetch a Booking",
      bm_event_id: bm_event_id,
      event_id: event_id,
      booking_id: booking_id,
      user_email: user&.email,
      user_name: user&.full_name,
      user_id: user&.id
    }
    Rails.logger.info "BusinessMatching Request Payload (Fetch a Booking): #{payload.inspect}"
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        Rails.logger.info "Fetch a Booking request accepted, waiting for async callback."
        return BaseService::ServiceResult.new(success: true, data: { message: "Fetch a Booking queued" })
      elsif response.data.is_a?(Hash)
        # Extract the booking data, handling nested structures like data.booking or just data
        raw_data = response.data
        booking_data = if raw_data["data"] && raw_data["data"]["booking"]
                         raw_data["data"]["booking"]
                       elsif raw_data["booking"]
                         raw_data["booking"]
                       else
                         raw_data["data"] || raw_data
                       end

        transformed_booking = _transform_bookings([booking_data], year).first
        return BaseService::ServiceResult.new(success: true, data: transformed_booking)
      else
        Rails.logger.warn "Fetch a Booking: Unexpected data format from 3rd party for synchronous response."
        return BaseService::ServiceResult.new(success: false, errors: "Unexpected data format", status: :internal_server_error)
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_all_bookings(event_id, force_refresh: false)
    # 1. Fetch all BM events for this system event
    Rails.logger.info "FetchAllBookings: Fetching events for event_id: #{event_id}"
    events_result = fetch_events(event_id, force_refresh: force_refresh)
    
    unless events_result.success?
      Rails.logger.error "FetchAllBookings: Failed to fetch events. #{events_result.errors}"
      return events_result 
    end

    all_bookings = []
    bm_events = events_result.data
    Rails.logger.info "FetchAllBookings: Found #{bm_events.size} BM events."

    # 2. Iterate and fetch bookings for each
    bm_events.each do |bm_event|
      Rails.logger.info "FetchAllBookings: Fetching bookings for BM Event #{bm_event[:id]} (#{bm_event[:title]})"
      bookings_result = fetch_bookings(bm_event[:id], event_id, force_refresh: force_refresh)
      
      if bookings_result.success?
        bookings = bookings_result.data[:bookings]
        Rails.logger.info "FetchAllBookings: Found #{bookings.size} bookings for #{bm_event[:title]}"
        
        # Enforce event title from the BM event if missing in bookings
        bookings.each { |b| b[:event_title] ||= bm_event[:title] }
        all_bookings.concat(bookings)
      else
        Rails.logger.error "FetchAllBookings: Failed to fetch bookings for BM Event #{bm_event[:id]}: #{bookings_result.errors}"
      end
    end

    Rails.logger.info "FetchAllBookings: Total bookings collected: #{all_bookings.size}"
    BaseService::ServiceResult.new(success: true, data: { bookings: all_bookings })
  end

  def transform_events(raw_events, event_id)
    # Pre-fetch host assignments from the new table
    host_assignments = BusinessHostAssignment.where(event_id: event_id).includes(:user)
    
    # Create a lookup map of { bm_event_id => user }
    host_lookup = host_assignments.each_with_object({}) do |assignment, memo|
      if assignment.business_matching_event_id.present? && assignment.user.present?
        # Map the session ID to the user object
        memo[assignment.business_matching_event_id] = assignment.user
      end
    end

    raw_events.map do |event_data|
      bm_event_id = event_data["id"] || event_data["_id"]
      host_user = host_lookup[bm_event_id]
      
      {
        id: bm_event_id,
        event_id: event_id, # Use event_id instead of internal_event_id
        title: event_data["title"],
        duration: event_data["slotDuration"],
        location: event_data["locationLink"],
        admin_email: event_data["adminEmail"],
        admin_wa_number: event_data["adminWaNumber"],
        host: host_user ? {
          id: host_user.id,
          full_name: host_user.full_name,
          email: host_user.email,
          phone: host_user.phone
        } : nil
      }
    end
  end

  private

  def _transform_events(raw_events, event_id)
    transform_events(raw_events, event_id)
  end

  def _transform_bookings(raw_bookings, year = Time.current.year)
    raw_bookings.map do |booking|
      formatted_date = _format_date_with_year(booking["bookingDate"], year)
      {
        id: booking["_id"] || booking["id"],
        name: booking["name"],
        email: booking["email"],
        phone: booking["phone"],
        date: formatted_date, # Original key
        booking_date: formatted_date, # Duplicate for consistency
        time: booking["bookingTime"], # Original key
        booking_time: booking["bookingTime"], # Duplicate for consistency
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
        potential_deal_value: (booking["detail3"].to_f rescue 0.0)
      }
    end
  end

  def _format_date_with_year(date_str, year)
    return date_str if date_str.blank?
    return date_str if date_str.match?(/\d{4}/) # Already has year
    "#{date_str} #{year}"
  end

  def _send_request(payload)
    event_id = payload[:event_id]
    event = Event.find_by(id: event_id) if event_id

    webhook_url = event&.business_matching_webhook_url.presence || WEBHOOK_URL

    # Determine dynamic receive URL
    base_url = ENV['API_HOST_URL'].presence
    base_url ||= if Rails.env.production?
                   "https://api.eventzflow.com"
                 elsif Rails.env.staging?
                   "https://staging-api.eventzflow.com"
                 else
                   "https://local-backend.eventzflow.com"
                 end

    receive_url = "#{base_url}/v1/business_matching/receive"
    payload[:receive_url] = receive_url

    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    # Bypass SSL verification to avoid "unable to get certificate CRL" error
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30

    # Use request_uri to handle cases where path is empty (it defaults to "/")
    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
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
