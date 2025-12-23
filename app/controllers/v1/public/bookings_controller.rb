# frozen_string_literal: true

module V1
  module Public
    class BookingsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/bookings/:id
      def show
        booking_id = params[:id]

        if booking_id.start_with?('Pending-')
          cached_booking = Rails.cache.read("pending_booking_#{booking_id}")
          if cached_booking
            return render json: cached_booking, status: :ok
          else
            # If not in cache, it might be a race condition or expired.
            # You could either return not_found or attempt to fetch anyway.
            # Returning not_found is safer to avoid hitting the external service with a fake ID.
            return render json: { error: 'Pending booking not found or expired.' }, status: :not_found
          end
        end
        
        event_id = params[:event_id]
        bm_event_id = params[:bm_event_id]

        # For public view, we don't have current_user. The service needs to handle this.
        service_result = BusinessMatchingService.new(nil).fetch_single_booking(bm_event_id, event_id, booking_id)

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Booking not found' }, status: :not_found
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end
    end
  end
end