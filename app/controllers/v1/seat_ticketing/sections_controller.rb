module V1
  module SeatTicketing
    class SectionsController < ApplicationController
      before_action :set_venue
      before_action :set_section, only: [:show, :update, :destroy]

      def index
        render json: @venue.event_seat_sections
      end

      def show
        render json: @section
      end

      def create
        @section = @venue.event_seat_sections.build(section_params)
        if @section.save
          render json: @section, status: :created
        else
          render json: { errors: @section.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @section.update(section_params)
          render json: @section
        else
          render json: { errors: @section.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @section.destroy
        head :no_content
      end

      private

      def set_venue
        load_seat_session
        load_seat_venue
      end

      def set_section
        load_seat_section
      end

      def section_params
        params.require(:section).permit(
          :name,
          :price,
          :start_row,
          :start_column,
          :seat_row,
          :seat_column,
          :row_span,
          :col_span
        )
      end
    end
  end
end
