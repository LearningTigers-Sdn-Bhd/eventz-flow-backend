module V1
  module SeatTicketing
    class EventTicketSeatsController < ApplicationController
      include SeatTicketingContext
      before_action :set_section
      before_action :set_ticket_seat, only: [:show, :update, :destroy, :lock, :unlock]

      skip_before_action :authenticate_user!, only: [:index, :show, :lock, :unlock]
      skip_before_action :require_verified_email!, only: [:index, :show, :lock, :unlock]

      def index
        authorize @session, :show?
        render json: @section.event_ticket_seats
      end

      def show
        authorize @ticket_seat
        render json: @ticket_seat
      end

      def lock
        # For public locking, we only authorize if the session is published
        if !@session.published?
          return error_response(message: 'Cannot lock seats in an unpublished session', status: :forbidden)
        end

        checkout_session_uuid = params[:checkout_session_uuid].presence
        if checkout_session_uuid.blank?
          return error_response(message: 'checkout_session_uuid is required', status: :bad_request)
        end

        authorize @ticket_seat

        # Idempotency check: if seat is already locked by the same checkout session, return success
        if @ticket_seat.locked? && @ticket_seat.locked_by_session_id == checkout_session_uuid
          return render json: @ticket_seat
        end

        checkout_session = EventSeatCheckoutSession.find_by(id: checkout_session_uuid)
        if checkout_session && checkout_session.event_seat_session_id != @session.id
          return error_response(message: 'Checkout session does not belong to this seat session', status: :forbidden)
        end
        checkout_session ||= EventSeatCheckoutSession.create!(
          id: checkout_session_uuid,
          event_seat_session_id: @session.id
        )
        checkout_session.touch

        if @ticket_seat.available?
          if @ticket_seat.update(locked_by_session_id: checkout_session.id)
            render json: @ticket_seat
          else
            render json: { errors: @ticket_seat.errors.full_messages }, status: :unprocessable_content
          end
        else
          render json: { error: "Seat is already #{@ticket_seat.status}" }, status: :conflict
        end
      end

      def unlock
        authorize @ticket_seat

        checkout_session_uuid = params[:checkout_session_uuid].presence
        if checkout_session_uuid.blank?
          return error_response(message: 'checkout_session_uuid is required', status: :bad_request)
        end

        # Idempotency check: if seat is already available, return success
        if @ticket_seat.available?
          return render json: @ticket_seat
        end

        if @ticket_seat.locked_by_session_id != checkout_session_uuid
          return error_response(message: 'You cannot unlock this seat', status: :forbidden)
        end

        if @ticket_seat.locked?
          if @ticket_seat.update(locked_by_session_id: nil)
            render json: @ticket_seat
          else
            render json: { errors: @ticket_seat.errors.full_messages }, status: :unprocessable_content
          end
        else
          render json: { error: "Seat is not locked" }, status: :unprocessable_content
        end
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
