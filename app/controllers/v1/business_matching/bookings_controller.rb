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
    end
  end
end
