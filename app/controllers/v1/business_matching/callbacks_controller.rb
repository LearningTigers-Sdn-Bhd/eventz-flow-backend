module V1
  module BusinessMatching
    class CallbacksController < ApplicationController
      # Skip CSRF check for API/Webhooks if not already handled by BaseController configuration
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :authenticate_user!, only: [:receive]
      skip_before_action :require_verified_email!, only: [:receive]

      # POST /api/v1/business_matching/receive
      def receive
        Rails.logger.info "BusinessMatching Callback Payload: #{params.inspect}"
        event_id = params[:event_id]
        bm_event_id = params[:bm_event_id]

        if event_id.blank?
          render json: { error: 'Missing event_id' }, status: :unprocessable_entity
          return
        end

        # Convert params to a regular hash after permitting all to ensure consistent key? behavior
        callback_data = params.permit!.to_h

        # --- Handling Event Details Callback ---
        # If the payload seems to be a list of events (e.g., contains 'title' or 'slotDuration' in first item)
        # Check if callback_data[:data] contains event details, not availability dates
        if callback_data[:data].is_a?(Array) && callback_data[:data].first.is_a?(Hash) && (callback_data[:data].first.key?("title") || callback_data[:data].first.key?("slotDuration"))
             event_details_data = callback_data[:data]
             Rails.logger.info "Caching Business Matching EVENT DETAILS data for event #{event_id}: #{event_details_data.size} items"

             # Transform the event details data to match frontend's BusinessMatchingEvent interface
             formatted_events = event_details_data.map do |event_data|
                {
                  id: event_data["id"] || event_data["_id"],
                  event_id: event_id, # Our internal event ID
                  title: event_data["title"],
                  duration: event_data["slotDuration"],
                  location: event_data["locationLink"],
                  admin_email: event_data["adminEmail"],
                  admin_wa_number: event_data["adminWaNumber"]
                }
             end
             Rails.cache.write("business_matching_events_#{event_id}", formatted_events, expires_in: 1.hour)
             Rails.logger.info "Cached Event Details Data: #{Rails.cache.read("business_matching_events_#{event_id}").inspect}"

        # --- Handling Detailed Slots Callback (Specific Date) ---
        # If the payload contains specific time slots (e.g., contains 'slot' singular key)
        elsif callback_data[:data].is_a?(Array) && callback_data[:data].first.is_a?(Hash) && callback_data[:data].first.key?("slot")
             detailed_slots_data = callback_data[:data]
             if bm_event_id.blank?
                 Rails.logger.warn "BusinessMatching Callback: Missing bm_event_id for detailed slots data. Cannot cache."
                 render json: { error: 'Missing bm_event_id for detailed slots data' }, status: :unprocessable_entity
                 return
             end
             
             # Extract date from the first slot to form the cache key
             date = detailed_slots_data.first["date"]
             if date.blank?
                 Rails.logger.warn "BusinessMatching Callback: Missing date in detailed slots data. Cannot cache."
                 render json: { error: 'Missing date in detailed slots data' }, status: :unprocessable_entity
                 return
             end

             Rails.logger.info "Caching Business Matching DETAILED SLOTS data for event #{event_id} (BM ID: #{bm_event_id}) on #{date}: #{detailed_slots_data.size} items"
             
             # Cache using the date-specific key
             cache_key = "business_matching_detailed_slots_#{event_id}_#{bm_event_id}_#{date.parameterize}"
             Rails.cache.write(cache_key, { slots: detailed_slots_data }, expires_in: 1.hour)
             Rails.logger.info "Cached Detailed Slots Data for key #{cache_key}"

        # --- Handling Availability Dates Callback (List of Dates) ---
        # If the payload contains availability dates (e.g., contains 'slots' plural count, AND NOT 'slot' singular)
        elsif callback_data[:data].is_a?(Array) && callback_data[:data].first.is_a?(Hash) && (callback_data[:data].first.key?("slots") || callback_data[:data].first.key?("date"))
             availability_data = callback_data[:data]
             if bm_event_id.blank?
                 Rails.logger.warn "BusinessMatching Callback: Missing bm_event_id for availability data. Cannot cache."
                 render json: { error: 'Missing bm_event_id for availability data' }, status: :unprocessable_entity
                 return
             end

             Rails.logger.info "Caching Business Matching AVAILABILITY DATES data for event #{event_id} (BM ID: #{bm_event_id}): #{availability_data.size} items"

             formatted_dates = availability_data.map do |item|
                {
                    day: item["day"],
                    date: item["date"],
                    slots: item["slots"].to_i
                }
             end
             Rails.cache.write("business_matching_availability_#{event_id}_#{bm_event_id}", { dates: formatted_dates }, expires_in: 1.hour)
             Rails.logger.info "Cached Availability Data: #{Rails.cache.read("business_matching_availability_#{event_id}_#{bm_event_id}").inspect}"

        # --- Handling Bookings Callback ---
        # If payload contains booking related keys
        elsif callback_data[:data].is_a?(Array) && callback_data[:data].first.is_a?(Hash) && callback_data[:data].first.key?("bookingDate")
             bookings_data = callback_data[:data]
             if bm_event_id.blank?
                 Rails.logger.warn "BusinessMatching Callback: Missing bm_event_id for bookings data. Cannot cache."
                 render json: { error: 'Missing bm_event_id for bookings data' }, status: :unprocessable_entity
                 return
             end
             
             Rails.logger.info "Caching Business Matching BOOKINGS data for event #{event_id} (BM ID: #{bm_event_id}): #{bookings_data.size} items"
             
             formatted_bookings = bookings_data.map do |booking|
                {
                    id: booking["_id"] || booking["id"],
                    name: booking["name"],
                    email: booking["email"],
                    phone: booking["phone"],
                    booking_date: booking["bookingDate"],
                    booking_time: booking["bookingTime"],
                    duration: booking["bookingDuration"],
                    status: booking["status"],
                    event_title: booking["eventTitle"],
                    location: booking["eventLocationLink"],
                    cancel_link: booking["cancelBookingLink"],
                    reschedule_link: booking["resheduleBookingLink"],
                    meeting_approval_link: booking["meetingApprovalLink"],
                    payment_status: booking["paymentStatus"],
                    created_at: booking["createdAt"]
                }
             end

             Rails.cache.write("business_matching_bookings_#{event_id}_#{bm_event_id}", { bookings: formatted_bookings }, expires_in: 1.hour)
             Rails.logger.info "Cached Bookings Data: #{Rails.cache.read("business_matching_bookings_#{event_id}_#{bm_event_id}").inspect}"

        else
             Rails.logger.warn "BusinessMatching Callback: Unrecognized data format in callback_data[:data]"
             render json: { error: 'Unrecognized data format' }, status: :unprocessable_entity
             return
        end

        # Broadcast the data to the frontend
        # Use callback_data now that it's a plain Hash
        payload = callback_data.except(:controller, :action).as_json
        ActionCable.server.broadcast("business_matching_event_#{event_id}", payload)

        render json: { status: 'received' }, status: :ok
      end
    end
  end
end
