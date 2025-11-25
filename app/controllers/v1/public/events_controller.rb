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
        @event = Event.friendly.find(params[:id])

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
    end
  end
end
