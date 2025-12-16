module V1
  module BusinessMatching
    class AvailabilityController < ApplicationController
      # GET /api/v1/business_matching/events/:business_matching_event_id/availability
      def index
        service_result = BusinessMatchingService.new(current_user).fetch_availability(
          params[:business_matching_event_id],
          params[:event_id], # Pass event_id
          force_refresh: params[:force_refresh] == 'true'
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      end

      # GET /api/v1/business_matching/events/:business_matching_event_id/availability/:date/slots
      def show_slots
        service_result = BusinessMatchingService.new(current_user).fetch_detailed_slots(
          params[:business_matching_event_id],
          params[:date],
          params[:event_id], # Pass event_id
          force_refresh: params[:force_refresh] == 'true'
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
