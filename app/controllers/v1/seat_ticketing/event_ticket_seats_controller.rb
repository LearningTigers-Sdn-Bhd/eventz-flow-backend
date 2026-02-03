module V1
  module SeatTicketing
    class EventTicketSeatsController < ApplicationController
      include SeatTicketingContext
      before_action :set_section
      before_action :set_ticket_seat, only: [:show, :update, :destroy]

      def index
        render json: @section.event_ticket_seats
      end

      def show
        render json: @ticket_seat
      end

      def create
        @ticket_seat = @section.event_ticket_seats.build(ticket_seat_params)
        if @ticket_seat.save
          render json: @ticket_seat, status: :created
        else
          render json: { errors: @ticket_seat.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @ticket_seat.update(ticket_seat_params)
          render json: @ticket_seat
        else
          render json: { errors: @ticket_seat.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @ticket_seat.destroy
        head :no_content
      end

      private

      def set_section
        load_seat_session
        load_seat_venue
        load_seat_section(param_key: :section_id)
      end

      def set_ticket_seat
        load_ticket_seat
      end

      def ticket_seat_params
        params.require(:ticket_seat).permit(:name, :extra_price, :row_set, :col_set, :ticket_id)
      end
    end
  end
end
