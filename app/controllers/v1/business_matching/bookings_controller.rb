module V1
  module BusinessMatching
    class BookingsController < ApplicationController
      # GET /api/v1/business_matching/events/:business_matching_event_id/bookings
      def index
        service_result = BusinessMatchingService.new(current_user).fetch_bookings(
          params[:business_matching_event_id],
          params[:event_id]
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
          params.permit(:name, :email, :phone, :note, :date, :time)
        )

        if service_result.success?
          render json: service_result.data, status: :created
        else
          render json: { errors: service_result.errors }, status: service_result.status || :unprocessable_entity
        end
      end

      # PUT/PATCH /api/v1/business_matching/events/:business_matching_event_id/bookings/:id
      def update
        service_result = BusinessMatchingService.new(current_user).update_booking(
          params[:business_matching_event_id],
          params[:event_id],
          params[:id],
          params.permit(:host_comment, :potential_deal_value, :attendance, :name, :email, :phone, :booking_date, :booking_time, :status, :payment_status)
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :unprocessable_entity
        end
      end
    end
  end
end
