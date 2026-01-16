# frozen_string_literal: true

module V1
  module Public
    # Public events controller - accessible without authentication
    # Used for public pages that need basic event info
    class EventsController < ApplicationController
      # Skip all authentication for public endpoints
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/events/:id
      # Returns basic event information (limited fields for public display)
      def show
        @event = Event.friendly.find(params[:slug])

        # Return only public-safe event information
        success_response(
          data: @event.as_json(only: [
            :id,
            :title,
            :slug,
            :description,
            :start_date,
            :end_date,
            :start_time,
            :end_time,
            :venue_name,
            :venue_address,
            :status
          ])
        )
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Event not found', status: :not_found)
      end

      # GET /v1/public/events/:id/business_matching_events
      def business_matching_events
        @event = Event.find_by!(id: params[:id])
        
        unless @event.use_business_matching
          return render json: { errors: "Business matching is not enabled for this event" }, status: :bad_request
        end

        service_result = BusinessMatchingService.new(nil).fetch_events(@event.id)

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
      end
    end
  end
end
