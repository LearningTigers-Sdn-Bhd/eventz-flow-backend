module V1
  module SeatTicketing
    class VenuesController < ApplicationController
      before_action :set_session
      before_action :set_venue, only: [:show, :update, :destroy]

      def index
        render json: @session.event_seat_venues
      end

      def show
        render json: @venue
      end

      def create
        @venue = @session.event_seat_venues.build(venue_params)
        if @venue.save
          render json: @venue, status: :created
        else
          render json: { errors: @venue.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @venue.update(venue_params)
          render json: @venue
        else
          render json: { errors: @venue.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @venue.destroy
        head :no_content
      end

      private

      def set_session
        @session = EventSeatSession.find(params[:session_id])
        authorize @session
      end

      def set_venue
        @venue = @session.event_seat_venues.find(params[:id])
      end

      def venue_params
        params.require(:venue).permit(:name, :row, :column, :image)
      end
    end
  end
end
