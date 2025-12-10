module V1
  module LuckyDraw
    class LuckyDrawParticipantsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/participants
      def index
        authorize @event, :show?

        # Build base query based on event's ticket/visitor system
        participants = build_participants_query

        # Apply filters
        participants = filter_by_type(participants) if params[:type].present?

        # Apply exclusion rules based on use_gifts config:
        # - When use_gifts is true: exclude winners (gift_winners), but NOT invalid participants
        # - When use_gifts is false: exclude invalid participants, but NOT winners
        if @session.use_gifts
          participants = exclude_winners(participants)
        else
          participants = exclude_invalid(participants)
        end

        participants = exclude_null_names(participants)

        success_response(
          data: participants.map { |p| format_participant_response(p) },
          message: 'Success'
        )
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

      def build_participants_query
        if @event.use_ticket
          # Event uses ticket system - return tickets
          Ticket.where(event_id: @event.id)
        else
          # Event uses visitor system - return visitors
          Visitor.where(event_id: @event.id)
        end
      end

      def filter_by_type(participants)
        type = params[:type]
        if type == 'ticket' && @event.use_ticket
          participants
        elsif type == 'visitor' && !@event.use_ticket
          participants
        else
          # Return empty result if type doesn't match event system
          participants.none
        end
      end

      def exclude_winners(participants)
        # Get all participants who have won ANY gift for this SESSION
        winner_ticket_ids = GiftWinner.joins(:gift)
                                       .where(gifts: { lucky_draw_session_id: @session.id })
                                       .where.not(ticket_id: nil)
                                       .pluck(:ticket_id)

        winner_visitor_ids = GiftWinner.joins(:gift)
                                      .where(gifts: { lucky_draw_session_id: @session.id })
                                      .where.not(visitor_id: nil)
                                      .pluck(:visitor_id)

        if @event.use_ticket
          participants.where.not(id: winner_ticket_ids)
        else
          participants.where.not(id: winner_visitor_ids)
        end
      end

      def exclude_invalid(participants)
        # Get all invalid participants for this SESSION
        invalid_ticket_ids = InvalidParticipant.where(lucky_draw_session_id: @session.id)
                                                .where.not(ticket_id: nil)
                                                .pluck(:ticket_id)

        invalid_visitor_ids = InvalidParticipant.where(lucky_draw_session_id: @session.id)
                                               .where.not(visitor_id: nil)
                                               .pluck(:visitor_id)

        if @event.use_ticket
          participants.where.not(id: invalid_ticket_ids)
        else
          participants.where.not(id: invalid_visitor_ids)
        end
      end

      def exclude_null_names(participants)
        if @event.use_ticket
          participants.where.not(attendee_name: [nil, ''])
        else
          participants.where.not(full_name: [nil, ''])
        end
      end

      def format_participant_response(participant)
        {
          id: participant.id,
          name: participant.is_a?(Ticket) ? participant.attendee_name : participant.full_name
        }
      end
    end
  end
end
