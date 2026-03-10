module V1
  module SeatTicketing
    class CheckoutSessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:show, :clear_locks, :heartbeat]
      skip_before_action :require_verified_email!, only: [:show, :clear_locks, :heartbeat]

      def show
        checkout_session = EventSeatCheckoutSession.find_by(id: params[:id])
        return error_response(message: "Checkout session not found", status: :not_found) if checkout_session.nil?

        render json: {
          id: checkout_session.id,
          event_seat_session_id: checkout_session.event_seat_session_id,
          updated_at: checkout_session.updated_at,
          expires_at: checkout_session.created_at + EventSeatCheckoutSession::LOCK_DURATION
        }
      end

      def heartbeat
        checkout_session = EventSeatCheckoutSession.find_by(id: params[:id])
        
        if checkout_session.nil?
          return render json: {
            success: true,
            expires_at: Time.current,
            message: "Session not found, heartbeat skipped."
          }
        end

        render json: {
          success: true,
          expires_at: checkout_session.created_at + EventSeatCheckoutSession::LOCK_DURATION
        }
      end

      def clear_locks
        checkout_session = EventSeatCheckoutSession.find_by(id: params[:id])
        
        if checkout_session.nil?
          return render json: {
            success: true,
            cleared: 0,
            message: "Checkout session not found, no locks to clear."
          }
        end

        # TODO: Add ownership validation (e.g. check client_ip or visitor token)
        # to ensure only the creator can clear their own locks.

        cleared = 0
        EventTicketSeat.where(locked_by_session_id: checkout_session.id).find_each do |seat|
          next if seat.locked_by_session_id.nil?

          seat.update(locked_by_session_id: nil)
          cleared += 1
        end

        checkout_session.destroy

        render json: {
          success: true,
          cleared: cleared
        }
      rescue ActiveRecord::ActiveRecordError => e
        error_response(message: e.message, status: :unprocessable_content)
      end
    end
  end
end
