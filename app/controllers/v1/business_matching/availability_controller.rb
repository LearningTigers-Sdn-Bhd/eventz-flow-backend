module V1
  module BusinessMatching
    class AvailabilityController < ApplicationController
      prepend_before_action { Rails.logger.info "DEBUG: Entering AvailabilityController filters" }
      skip_default_authentication only: [:index, :show_slots]

      # GET /api/v1/business_matching/events/:business_matching_event_id/availability
      def index
        Rails.logger.info "DEBUG: Entering AvailabilityController#index"
        begin
          # Use current_user if available, otherwise nil (handled by service)
          service_result = ::BusinessMatchingService.new(current_user).fetch_availability(
            params[:business_matching_event_id],
            params[:event_id], # Pass event_id
            force_refresh: params[:force_refresh] == 'true'
          )

          if service_result.success?
            render json: service_result.data, status: :ok
          else
            render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
          end
        rescue Exception => e
          Rails.logger.error "AvailabilityController#index ERROR: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
        end
      end

      # GET /api/v1/business_matching/events/:business_matching_event_id/availability/:date/slots
      def show_slots
        begin
          service_result = ::BusinessMatchingService.new(current_user).fetch_detailed_slots(
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
        rescue Exception => e
          Rails.logger.error "AvailabilityController#show_slots ERROR: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
        end
      end
    end
  end
end
