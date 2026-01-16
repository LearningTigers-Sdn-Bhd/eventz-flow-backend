module V1
  module Roulette
    class RouletteWinnersController < ApplicationController
      before_action :set_event
      before_action :set_session
      before_action :set_winner, only: [:destroy]

      # GET /v1/events/:event_id/roulette/sessions/:session_id/winners
      def index
        authorize @session, :show?
        @winners = @session.roulette_winners.includes(:roulette_prize, :ticket, :visitor).order(drawn_at: :desc)

        success_response(
          data: @winners.map { |w| format_winner_response(w) },
          message: 'Success'
        )
      end

      # POST /v1/roulette/sessions/:session_id/winners
      def create
        ticket_public_id = params[:ticket_public_id]
        visitor_public_id = params[:visitor_public_id]
        prize_id = params[:prize_id]

        # Validate exactly one of ticket_public_id or visitor_public_id is provided
        unless (ticket_public_id.present? && visitor_public_id.blank?) ||
               (ticket_public_id.blank? && visitor_public_id.present?)
          return error_response(
            message: 'Exactly one of ticket_public_id or visitor_public_id must be provided',
            status: :unprocessable_content
          )
        end

        unless prize_id.present?
          return error_response(
            message: 'prize_id is required',
            status: :unprocessable_content
          )
        end

        # Find the prize
        prize = @session.roulette_prizes.find_by(id: prize_id)
        unless prize
          return error_response(
            message: 'Prize not found',
            status: :not_found
          )
        end

        # Resolve ticket or visitor from public_id
        ticket = nil
        visitor = nil

        if ticket_public_id.present?
          ticket = Ticket.find_by(public_id: ticket_public_id)
          unless ticket
            return error_response(
              message: 'Ticket not found',
              status: :not_found
            )
          end
        else
          visitor = Visitor.find_by(public_id: visitor_public_id)
          unless visitor
            return error_response(
              message: 'Visitor not found',
              status: :not_found
            )
          end
        end

        # Check if prize has available quantity
        if prize.remaining_quantity <= 0
          return error_response(
            message: 'Prize quantity exhausted',
            status: :unprocessable_content
          )
        end

        # Enforce is_multiple business rule
        unless @session.is_multiple
          # If is_multiple is false, only allow one winner per prize
          if prize.has_winner?
            return error_response(
              message: 'This prize already has a winner. Multiple winners are not allowed for this session.',
              status: :unprocessable_content
            )
          end
        end

        # Build winner for authorization
        @winner = @session.roulette_winners.build(
          roulette_prize: prize,
          ticket: ticket,
          visitor: visitor,
          drawn_at: Time.current
        )

        # Authorize winner creation
        authorize @winner, :create?

        # Create winner in a transaction
        ActiveRecord::Base.transaction do
          unless @winner.save
            return error_response(
              message: 'Validation failed',
              errors: format_validation_errors(@winner),
              status: :unprocessable_content
            )
          end
        end

        success_response(
          data: format_winner_response(@winner.reload),
          message: 'Winner created successfully',
          status: :created
        )
      end

      # DELETE /v1/events/:event_id/roulette/sessions/:session_id/winners/:id
      def destroy
        authorize @winner
        prize = @winner.roulette_prize
        @winner.destroy
        # Reload prize to get updated winners count
        prize.reload
        success_response(
          data: format_prize_response(prize),
          message: 'Winner removed successfully'
        )
      end

      private

      def set_event
        @event = Event.friendly.find(params[:event_id])
      end

      def set_session
        @session = @event.roulette_sessions.find(params[:session_id])
      end

      def set_winner
        @winner = @session.roulette_winners.find(params[:id])
      end

      def format_winner_response(winner)
        {
          id: winner.id,
          roulette_session_id: winner.roulette_session_id,
          roulette_prize_id: winner.roulette_prize_id,
          prize_name: winner.roulette_prize.name,
          ticket_id: winner.ticket_id,
          visitor_id: winner.visitor_id,
          participant_name: winner.ticket&.attendee_name || winner.visitor&.full_name,
          drawn_at: winner.drawn_at.iso8601,
          created_at: winner.created_at.iso8601,
          updated_at: winner.updated_at.iso8601
        }
      end

      def format_prize_response(prize)
        {
          id: prize.id,
          roulette_session_id: prize.roulette_session_id,
          name: prize.name,
          quantity: prize.quantity,
          remaining_quantity: prize.remaining_quantity,
          image_url: prize.image.attached? ? url_for(prize.image) : nil,
          winners: prize.roulette_winners.map { |w| format_winner_response(w) },
          created_at: prize.created_at.iso8601,
          updated_at: prize.updated_at.iso8601
        }
      end
    end
  end
end
