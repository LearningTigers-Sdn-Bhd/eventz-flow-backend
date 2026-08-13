module V1
  module LuckyDraw
    class LuckyDrawParticipantsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/participants
      def index
        authorize @session, :show?

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
        authorize @session, :show?
      end

      def build_participants_query
        leadable_type = @event.use_ticket ? 'Ticket' : 'Visitor'
        base = leadable_type == 'Ticket' ? Ticket : Visitor
        scope = base.where(event_id: @event.id)

        # Exhibitors draw from their own captured leads only, not the whole event's attendees
        return scope.where(id: own_lead_ids(leadable_type)) if current_user.exhibitor_for?(@event)

        scope
      end

      def own_event_vendor
        @own_event_vendor ||= EventVendor.find_by(event_id: @event.id, vendor_id: current_user.id)
      end

      def own_lead_ids(leadable_type)
        return [] unless own_event_vendor

        EventLead.where(event_vendor_id: own_event_vendor.id, leadable_type: leadable_type)
                 .pluck(:leadable_id)
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
