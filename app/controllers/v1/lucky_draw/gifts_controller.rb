module V1
  module LuckyDraw
    class GiftsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event
      before_action :set_gift, only: [:show, :update, :destroy]

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts
      def index
        @gifts = @session.gifts.includes(gift_winners: [:ticket, :visitor]).ordered.where('winner_counts > 0')
        
        # We use a dummy gift associated with the session for authorization
        authorize Gift.new(lucky_draw_session: @session)

        success_response(
          data: @gifts.map { |gift| format_gift_response(gift) },
          message: 'Success'
        )
      end

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:id
      def show
        authorize @gift
        @gift.reload
        @gift.gift_winners.includes(:ticket, :visitor).load
        success_response(
          data: format_gift_response(@gift),
          message: 'Success'
        )
      end

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts
      def create
        # Calculate order if not provided
        order = gift_params[:order] || Gift.next_order(@session.id)

        # Use winner_counts from params or default to 1 (must be > 0)
        winner_counts = gift_params[:winner_counts] || 1

        @gift = @session.gifts.build(gift_params.merge(order: order, winner_counts: winner_counts))
        
        authorize @gift

        if @gift.save
          success_response(
            data: format_gift_response(@gift.reload),
            message: 'Success',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@gift),
            status: :unprocessable_content
          )
        end
      end

      # PUT /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:id
      def update
        authorize @gift

        if @gift.update(gift_params)
          success_response(
            data: format_gift_response(@gift.reload),
            message: 'Success'
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@gift),
            status: :unprocessable_content
          )
        end
      end

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:id
      def destroy
        authorize @gift
        @gift.destroy
        head :no_content
      end

      private

      def set_event
        @event = Event.find_by!(id: params[:event_id])
      end

      def set_session
        @session = @event.lucky_draw_sessions.find(params[:session_id])
      end

      def authorize_event
        authorize @event, :show?
      end

      def set_gift
        @gift = @session.gifts.find_by!(id: params[:id])
      end

      def gift_params
        params.permit(:name, :order, :winner_counts)
      end

      def format_gift_response(gift)
        {
          id: gift.id,
          lucky_draw_session_id: gift.lucky_draw_session_id,
          name: gift.name,
          order: gift.order,
          winner_counts: gift.winner_counts,
          winners: gift.gift_winners.map { |winner| format_winner_response(winner) },
          created_at: gift.created_at.iso8601,
          updated_at: gift.updated_at.iso8601
        }
      end

      def format_winner_response(winner)
        # Get participant name from ticket or visitor
        # Associations should already be loaded via includes, but accessing them will trigger loading if needed
        participant_name = if winner.ticket_id
                             winner.ticket&.attendee_name
                           elsif winner.visitor_id
                             winner.visitor&.full_name
                           else
                             nil
                           end

        {
          id: winner.id,
          gift_id: winner.gift_id,
          ticket_id: winner.ticket_id,
          visitor_id: winner.visitor_id,
          participant_name: participant_name,
          drawn_at: winner.drawn_at.iso8601,
          created_at: winner.created_at.iso8601,
          updated_at: winner.updated_at.iso8601
        }
      end
    end
  end
end