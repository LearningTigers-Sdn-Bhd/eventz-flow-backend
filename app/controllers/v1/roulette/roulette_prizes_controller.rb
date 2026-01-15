module V1
  module Roulette
    class RoulettePrizesController < ApplicationController
      before_action :set_session
      before_action :set_prize, only: [:show, :update, :destroy]

      # GET /v1/roulette/sessions/:session_id/prizes
      def index
        authorize @session, :show?
        @prizes = @session.roulette_prizes.ordered.includes(:roulette_winners)

        success_response(
          data: @prizes.map { |p| format_prize_response(p) },
          message: 'Success'
        )
      end

      # GET /v1/roulette/sessions/:session_id/prizes/:id
      def show
        authorize @session, :show?
        success_response(
          data: format_prize_response(@prize),
          message: 'Success'
        )
      end

      # POST /v1/roulette/sessions/:session_id/prizes
      def create
        authorize @session, :update?

        @prize = @session.roulette_prizes.build(prize_params)

        # Handle image upload via Active Storage
        if params[:image].present?
          @prize.image.attach(params[:image])
        end

        if @prize.save
          success_response(
            data: format_prize_response(@prize),
            message: 'Prize created successfully',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@prize),
            status: :unprocessable_content
          )
        end
      end

      # PUT /v1/roulette/sessions/:session_id/prizes/:id
      def update
        authorize @session, :update?

        # Handle image removal
        if params[:remove_image] == 'true' || params[:remove_image] == true
          @prize.image.purge if @prize.image.attached?
        elsif params[:image].present?
          @prize.image.attach(params[:image])
        end

        if @prize.update(prize_params)
          success_response(
            data: format_prize_response(@prize),
            message: 'Prize updated successfully'
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@prize),
            status: :unprocessable_content
          )
        end
      end

      # DELETE /v1/roulette/sessions/:session_id/prizes/:id
      def destroy
        authorize @session, :update?
        @prize.destroy
        success_response(
          message: 'Prize deleted successfully'
        )
      end

      private

      def set_session
        @session = RouletteSession.find(params[:session_id])
      end

      def set_prize
        @prize = @session.roulette_prizes.find(params[:id])
      end

      def prize_params
        params.permit(:name, :quantity)
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

      def format_winner_response(winner)
        {
          id: winner.id,
          ticket_id: winner.ticket_id,
          visitor_id: winner.visitor_id,
          participant_name: winner.ticket&.attendee_name || winner.visitor&.full_name,
          drawn_at: winner.drawn_at.iso8601,
          created_at: winner.created_at.iso8601
        }
      end
    end
  end
end
