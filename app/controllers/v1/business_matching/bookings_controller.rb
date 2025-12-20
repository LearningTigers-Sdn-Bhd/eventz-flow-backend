module V1
  module BusinessMatching
    class BookingsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:public_create]
      skip_before_action :require_verified_email!, only: [:public_create]

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
        
        # Extract host_user_id from booking_params (if present)
        host_user_id = booking_params[:host_user_id] # Assuming host_user_id can be sent in booking_params

        service_result = BusinessMatchingService.new(current_user).update_booking(
          permitted_top_level_params[:business_matching_event_id],
          permitted_top_level_params[:event_id],
          permitted_top_level_params[:id], # This is the booking_id
          booking_params,
          host_user_id: host_user_id # Pass the host_user_id
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      end

      # POST /api/v1/business_matching/events/:event_id/bookings/public
      def public_create
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        # The service should handle a nil current_user for public bookings.
        service_result = BusinessMatchingService.new(current_user).public_create_booking(
          params[:business_matching_event_id],
          params[:event_id],
          params[:host_user_id], # Pass param directly, no local validation
          public_booking_create_params
        )

        if service_result.success?
          render json: service_result.data, status: :created
        else
          render json: { errors: service_result.errors }, status: service_result.status || :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        render json: { errors: e.message }, status: :bad_request
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
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

      # GET /api/v1/business_matching/events/:business_matching_event_id/bookings/generate_report
      # OR
      # GET /api/v1/business_matching/events/:event_id/report
      def generate_report
        bm_event_ids = params[:business_matching_event_ids]
        
        all_bookings = []
        service_error_occurred = false

        if bm_event_ids.present? && bm_event_ids.is_a?(Array)
          # Fetch bookings for specific BM event IDs
          bm_event_ids.each do |bm_event_id|
            service_result = BusinessMatchingService.new(current_user).fetch_bookings(
              bm_event_id,
              params[:event_id],
              force_refresh: true # Always force refresh for reports
            )
            if service_result.success?
              all_bookings.concat(service_result.data[:bookings])
            else
              render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
              service_error_occurred = true
              break # Stop processing on first error
            end
          end
        else
          # Fallback: Fetch all bookings for the event
          service_result = BusinessMatchingService.new(current_user).fetch_all_bookings(params[:event_id], force_refresh: true)
          if service_result.success?
            all_bookings.concat(service_result.data[:bookings])
          else
            render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
            service_error_occurred = true
          end
        end

        unless service_error_occurred
          report_service = BusinessMatchingReportService.new(all_bookings, "Business Matching Report")

          respond_to do |format|
            format.xlsx do
              send_data report_service.generate_xlsx,
                        filename: "business_matching_report_#{params[:event_id]}.xlsx",
                        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                        disposition: "attachment"
            end
          end
        end
      end
    
      private # Add this line

      def booking_params
        params.require(:booking).permit(
          :name, :email, :phone, :booking_date, :booking_time, :status, :payment_status,
          :attendance, :host_comment, :potential_deal_value, :host_user_id
        )
      end

      def public_booking_create_params
        params.require(:booking).permit(
          :name, :email, :phone, :date, :time
        )
      end
    end
  end
end
