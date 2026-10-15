module V1
  module Roulette
    class RouletteParticipantsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event

      # GET /v1/events/:event_id/roulette/sessions/:session_id/participants/:id
      # Fetches a ticket or visitor by public_id or id for roulette feature
      # Supports both public_id (UUID) and internal id (integer)
      def show
        authorize @session, :show?

        # Determine if event uses tickets or visitors
        if @event.use_ticket
          # First check if participant exists globally (for error message distinction)
          global_participant = find_ticket_globally(params[:id])
          @participant = find_ticket(params[:id])
          participant_type = 'ticket'
        else
          # First check if participant exists globally (for error message distinction)
          global_participant = find_visitor_globally(params[:id])
          @participant = find_visitor(params[:id])
          participant_type = 'visitor'
        end

        # If participant doesn't exist at all, return "Participant not found"
        if global_participant.nil?
          render json: { error: 'Participant not found' }, status: :not_found
          return
        end

        # If participant exists but doesn't belong to this event, return specific error
        unless global_participant.event_id == @event.id
          render json: { error: 'Participant not found in this event' }, status: :not_found
          return
        end

        # Exhibitors only draw from their own captured leads, not the whole event
        if @participant.nil? && exhibitor_scoped?
          render json: { error: 'Participant not found in your leads' }, status: :not_found
          return
        end

        # Participant belongs to current event, return success
        success_response(
          data: format_participant_response(@participant, participant_type),
          message: 'Success'
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Participant not found' }, status: :not_found
      end

      private

      def set_event
        @event = Event.find_by!(id: params[:event_id])
      end

      def set_session
        @session = @event.roulette_sessions.find(params[:session_id])
      end

      def authorize_event
        authorize @session, :show?
      end

      # Exhibitors draw from their own captured leads only, everyone else (admins) from the full event
      def exhibitor_scoped?
        current_user.exhibitor_for?(@event)
      end

      def own_event_vendor
        @own_event_vendor ||= EventVendor.find_by(event_id: @event.id, vendor_id: current_user.id)
      end

      # Find ticket by public_id (UUID) or id (integer) - within current event,
      # scoped to the exhibitor's own captured leads when applicable
      def find_ticket(identifier)
        scope = Ticket.where(event_id: @event.id).includes(:ticket_type, :event, :scanned_by)
        scope = scope_to_leads(scope, 'Ticket') if exhibitor_scoped?

        scope.find_by(public_id: identifier) || scope.find_by(id: identifier)
      end

      # Find visitor by public_id (UUID) or id (integer) - within current event,
      # scoped to the exhibitor's own captured leads when applicable
      def find_visitor(identifier)
        scope = Visitor.where(event_id: @event.id).includes(:event, :scanned_by)
        scope = scope_to_leads(scope, 'Visitor') if exhibitor_scoped?

        scope.find_by(public_id: identifier) || scope.find_by(id: identifier)
      end

      def scope_to_leads(scope, leadable_type)
        return scope.none unless own_event_vendor

        lead_ids = EventLead.where(event_vendor_id: own_event_vendor.id, leadable_type: leadable_type)
                             .pluck(:leadable_id)
        scope.where(id: lead_ids)
      end

      # Find ticket globally (across all events) - used only for error message distinction
      def find_ticket_globally(identifier)
        # Try public_id first (UUID format)
        ticket = Ticket.find_by(public_id: identifier)
        return ticket if ticket

        # Fallback to internal id
        Ticket.find_by(id: identifier)
      end

      # Find visitor globally (across all events) - used only for error message distinction
      def find_visitor_globally(identifier)
        # Try public_id first (UUID format)
        visitor = Visitor.find_by(public_id: identifier)
        return visitor if visitor

        # Fallback to internal id
        Visitor.find_by(id: identifier)
      end

      # Format participant response (ticket or visitor)
      def format_participant_response(participant, type)
        if type == 'ticket'
          {
            type: 'ticket',
            id: participant.id,
            public_id: participant.public_id,
            attendee_name: participant.attendee_name,
            attendee_email: participant.attendee_email,
            attendee_phone: participant.attendee_phone,
            role: participant.role,
            checked_in: participant.checked_in,
            check_in_at: participant.check_in_at&.iso8601,
            status: participant.status,
            ticket_type: participant.ticket_type ? {
              id: participant.ticket_type.id,
              name: participant.ticket_type.name,
              price: participant.ticket_type.price.to_f
            } : nil,
            event: {
              id: participant.event.id,
              title: participant.event.title
            },
            scanned_by: participant.scanned_by ? {
              id: participant.scanned_by.id,
              full_name: participant.scanned_by.full_name
            } : nil
          }
        else # visitor
          {
            type: 'visitor',
            id: participant.id,
            public_id: participant.public_id,
            full_name: participant.full_name,
            email: participant.email,
            phone: participant.phone,
            role: participant.role,
            gender: participant.gender,
            age: participant.age,
            checked_in: participant.checked_in,
            check_in_at: participant.check_in_at&.iso8601,
            event: {
              id: participant.event.id,
              title: participant.event.title
            },
            scanned_by: participant.scanned_by ? {
              id: participant.scanned_by.id,
              full_name: participant.scanned_by.full_name
            } : nil
          }
        end
      end
    end
  end
end
