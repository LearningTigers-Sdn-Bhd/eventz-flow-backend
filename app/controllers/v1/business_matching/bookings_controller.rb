module V1
  module BusinessMatching
    class BookingsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:public_create, :public_show, :reschedule, :cancel]
      skip_before_action :require_verified_email!, only: [:public_create, :public_show, :reschedule, :cancel]

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

      # POST /api/v1/business_matching/events/:event_id/report?format=xlsx
      def generate_report
        bm_event_ids = params[:business_matching_event_ids]
        report_format = (params[:format].presence || 'xlsx').to_s.downcase

        all_bookings = []
        service_error_occurred = false

        if bm_event_ids.present? && bm_event_ids.is_a?(Array)
          bm_event_ids.each do |bm_event_id|
            service_result = BusinessMatchingService.new(current_user).fetch_bookings(
              bm_event_id,
              params[:event_id],
              force_refresh: true
            )
            if service_result.success?
              all_bookings.concat(service_result.data[:bookings])
            else
              render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
              service_error_occurred = true
              break
            end
          end
        else
          service_result = BusinessMatchingService.new(current_user).fetch_all_bookings(params[:event_id], force_refresh: true)
          if service_result.success?
            all_bookings.concat(service_result.data[:bookings])
          else
            render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
            service_error_occurred = true
          end
        end

        return if service_error_occurred

        report_service = BusinessMatchingReportService.new(all_bookings, "Business Matching Report")

        case report_format
        when 'xlsx'
          send_data report_service.generate_xlsx,
                    filename: "business_matching_report_#{params[:event_id]}.xlsx",
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        else
          render json: { errors: "Unsupported format: #{report_format}. Use 'xlsx'." }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error("Report generation failed: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        render json: { errors: e.message }, status: :internal_server_error
      end

      # GET /api/v1/business_matching/bookings/:id/public
      def public_show
        booking = BusinessMatchingBooking.find_by(id: params[:id])
        return render json: { error: 'Booking not found' }, status: :not_found unless booking

        session = booking.business_matching_session
        render json: {
          id: booking.id.to_s,
          name: booking.name,
          email: booking.email,
          booking_date: booking.booking_date.strftime('%-d %B %Y'),
          booking_time: booking.booking_time,
          status: booking.status,
          event_id: session&.event_id.to_s,
          bm_event_id: session&.id.to_s,
          session_title: session&.title || 'Matchmaking Session',
          host_user_id: booking.host_user_id.to_s,
          slot_duration: session&.slot_duration
        }, status: :ok
      end

      # PATCH /api/v1/business_matching/bookings/:id/reschedule
      def reschedule
        booking = BusinessMatchingBooking.find_by(id: params[:id])
        return render json: { error: 'Booking not found' }, status: :not_found unless booking
        return render json: { error: 'Cancelled bookings cannot be rescheduled' }, status: :unprocessable_entity if booking.status == 'Cancelled'

        new_date = params[:date].presence
        new_time = params[:time].presence
        return render json: { error: 'New date and time are required' }, status: :bad_request unless new_date && new_time

        parsed_date = Date.parse(new_date)

        # Check slot is not already taken
        conflict = BusinessMatchingBooking
                     .where(host_user_id: booking.host_user_id, booking_date: parsed_date, booking_time: new_time)
                     .where.not(id: booking.id)
                     .where.not(status: 'Cancelled')
                     .exists?

        return render json: { error: 'That slot is already booked. Please choose another time.' }, status: :conflict if conflict

        if booking.update(booking_date: parsed_date, booking_time: new_time)
          session = booking.business_matching_session
          ActionCable.server.broadcast("business_matching_event_#{session&.event_id}", { action: 'booking_rescheduled' })
          render json: {
            message: 'Booking rescheduled successfully',
            booking_date: booking.booking_date.strftime('%-d %B %Y'),
            booking_time: booking.booking_time
          }, status: :ok
        else
          render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
        end
      rescue Date::Error
        render json: { error: 'Invalid date format' }, status: :bad_request
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # PATCH /api/v1/business_matching/bookings/:id/cancel
      def cancel
        booking = BusinessMatchingBooking.find_by(id: params[:id])
        return render json: { error: 'Booking not found' }, status: :not_found unless booking
        return render json: { error: 'Booking is already cancelled' }, status: :unprocessable_entity if booking.status == 'Cancelled'

        if booking.update(status: 'Cancelled')
          session = booking.business_matching_session
          ActionCable.server.broadcast("business_matching_event_#{session&.event_id}", { action: 'booking_cancelled' })
          render json: {
            message: 'Booking cancelled successfully',
            status: booking.status
          }, status: :ok
        else
          render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
        end
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
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
          :name, :email, :phone, :date, :time, :note
        )
      end
    end
  end
end
