module V1
  module BusinessMatching
    class BookingsController < ApplicationController
      # GET /api/v1/business_matching/events/:business_matching_event_id/bookings
      def index
        service_result = BusinessMatchingService.new(current_user).fetch_bookings(
          params[:business_matching_event_id],
          params[:event_id],
          force_refresh: params[:force_refresh] == 'true'
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      end

      # POST /api/v1/business_matching/events/:business_matching_event_id/bookings
      def create
        service_result = BusinessMatchingService.new(current_user).create_booking(
          params[:business_matching_event_id],
          params[:event_id],
          params.require(:booking).permit(:name, :email, :phone, :note, :date, :time)
        )

        if service_result.success?
          render json: service_result.data, status: :created
        else
          render json: { errors: service_result.errors }, status: service_result.status || :unprocessable_entity
        end
      end

      # PUT/PATCH /api/v1/business_matching/events/:business_matching_event_id/bookings/:id
      def update
        # Permit top-level parameters relevant to the update action, including the 'booking' hash
        permitted_top_level_params = params.permit(:event_id, :business_matching_event_id, :id, booking: {})

        service_result = BusinessMatchingService.new(current_user).update_booking(
          permitted_top_level_params[:business_matching_event_id],
          permitted_top_level_params[:event_id],
          permitted_top_level_params[:id], # This is the booking_id
          booking_params
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      end

      # GET /api/v1/business_matching/events/:business_matching_event_id/bookings/:id
      def show
        # Permit top-level parameters for fetching a single booking
        permitted_params = params.permit(:event_id, :business_matching_event_id, :id)

        service_result = BusinessMatchingService.new(current_user).fetch_single_booking(
          permitted_params[:business_matching_event_id],
          permitted_params[:event_id],
          permitted_params[:id] # This is the booking_id
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      end
    
      private # Add this line

      def booking_params
        params.require(:booking).permit(
          :name, :email, :phone, :booking_date, :booking_time, :status, :payment_status,
          :attendance, :host_comment, :potential_deal_value
        )
      end
    end
  end
end
