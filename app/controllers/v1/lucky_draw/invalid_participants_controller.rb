module V1
  module LuckyDraw
    class InvalidParticipantsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event
      before_action :set_invalid_participant, only: [:destroy]

      # GET /v1/events/:event_id/lucky_draw/sessions/:session_id/invalid_participants
      def index
        authorize InvalidParticipant.new(lucky_draw_session: @session)

        @invalid_participants = @session.invalid_participants.includes(:ticket, :visitor)

        success_response(
          data: @invalid_participants.map { |ip| format_invalid_participant_response(ip) },
          message: 'Success'
        )
      end

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/invalid_participants
      def create
        authorize InvalidParticipant.new(lucky_draw_session: @session)

        @invalid_participant = @session.invalid_participants.build(invalid_participant_params)

        if @invalid_participant.save
          success_response(
            data: format_invalid_participant_response(@invalid_participant),
            message: 'Success',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@invalid_participant),
            status: :unprocessable_content
          )
        end
      end

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:session_id/invalid_participants/:id
      def destroy
        authorize @invalid_participant
        @invalid_participant.destroy
        head :no_content
      end

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:session_id/invalid_participants (destroy_all)
      def destroy_all
        authorize InvalidParticipant.new(lucky_draw_session: @session)
        @session.invalid_participants.destroy_all
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

      def set_invalid_participant
        @invalid_participant = @session.invalid_participants.find_by!(id: params[:id])
      end

      def invalid_participant_params
        params.permit(:ticket_id, :visitor_id)
      end

      def format_invalid_participant_response(invalid_participant)
        participant = invalid_participant.ticket || invalid_participant.visitor
        participant_id = invalid_participant.ticket_id || invalid_participant.visitor_id
        participant_name = if invalid_participant.ticket
                            invalid_participant.ticket.attendee_name
                          else
                            invalid_participant.visitor&.full_name
                          end

        {
          id: invalid_participant.id,
          lucky_draw_session_id: invalid_participant.lucky_draw_session_id,
          participant: {
            id: participant_id,
            name: participant_name
          },
          created_at: invalid_participant.created_at.iso8601,
          updated_at: invalid_participant.updated_at.iso8601
        }
      end
    end
  end
end