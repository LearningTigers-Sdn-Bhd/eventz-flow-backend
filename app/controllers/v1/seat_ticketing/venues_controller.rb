module V1
  module SeatTicketing
    class VenuesController < ApplicationController
      include Rails.application.routes.url_helpers
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

      def venue_as_json(venue)
        venue.as_json.merge(
          image_url: venue_image_url(venue)
        )
      end

      def venue_image_url(venue)
        return nil unless venue.image.attached?

        url_options = (Rails.application.routes.default_url_options || {}).dup
        if respond_to?(:request) && request.present?
          url_options[:host] = request.host
          url_options[:protocol] = request.protocol.gsub('://', '')
          url_options[:port] = request.port unless [80, 443].include?(request.port)
        end

        rails_blob_url(venue.image, **url_options)
      rescue => e
        Rails.logger.error "Could not generate URL for venue #{venue.id}: #{e.message}"
        nil
      end

      def set_session
        @session = EventSeatSession.find(params[:session_id])
        authorize @session
      end

      def set_venue
        @venue = @session.event_seat_venues.find(params[:id])
      end

      def venue_params
        params.require(:venue).permit(:name, :total_row, :total_column, :image, :aspect_ratio)
      end
    end
  end
end
