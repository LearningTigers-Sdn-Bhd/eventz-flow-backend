module V1
  module SeatTicketing
    class VenuesController < ApplicationController
      include SeatTicketingContext
      before_action :set_session
      before_action :set_venue, only: [:show, :update, :destroy, :attach_image]

      def index
        render json: @session.event_seat_venues.map { |v| venue_as_json(v) }
      end

      def show
        render json: venue_as_json(@venue)
      end

      def create
        @venue = @session.event_seat_venues.build(venue_params)
        if @venue.save
          render json: venue_as_json(@venue), status: :created
        else
          render json: { errors: @venue.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @venue.update(venue_params)
          render json: venue_as_json(@venue)
        else
          render json: { errors: @venue.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @venue.destroy
        head :no_content
      end

      def attach_image
        if params[:image].present?
          @venue.image.attach(params[:image])
          render json: venue_as_json(@venue)
        else
          render json: { error: 'No image provided' }, status: :bad_request
        end
      end

      private
      def set_session
        load_seat_session
      end

      def set_venue
        load_seat_venue(param_key: :id)
      end

      def venue_params
        params.require(:venue).permit(:name, :total_row, :total_column, :image, :aspect_ratio)
      end
    end
  end
end
