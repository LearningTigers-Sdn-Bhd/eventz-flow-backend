module V1
  module LuckyDraw
    class InvalidParticipantsController < ApplicationController
      # Load and authorize the parent event and session before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event
      before_action :set_invalid_participant, only: [:destroy, :notify]

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
          # Send webhook notification if webhook_url is configured
          send_winner_webhook(@invalid_participant)

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

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/invalid_participants/:id/notify
      def notify
        authorize @invalid_participant, :notify?

        webhook_url = @event.webhook_url
        unless webhook_url.present?
          return error_response(
            message: 'No webhook URL configured for this event',
            status: :unprocessable_content
          )
        end

        send_winner_webhook(@invalid_participant)

        success_response(
          data: format_invalid_participant_response(@invalid_participant),
          message: 'Notification sent successfully'
        )
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

      def send_winner_webhook(invalid_participant)
        webhook_url = @event.webhook_url
        return unless webhook_url.present?

        payload = build_winner_webhook_payload(invalid_participant)
        WebhookSenderJob.perform_later(webhook_url, payload)
      rescue StandardError => e
        # Log error but don't fail the request
        Rails.logger.error "Failed to queue webhook: #{e.message}"
      end

      def build_winner_webhook_payload(invalid_participant)
        participant = invalid_participant.ticket || invalid_participant.visitor
        participant_data = if invalid_participant.ticket
          {
            type: 'ticket',
            id: invalid_participant.ticket.id,
            public_id: invalid_participant.ticket.public_id,
            name: invalid_participant.ticket.attendee_name,
            email: invalid_participant.ticket.attendee_email,
            phone: invalid_participant.ticket.attendee_phone
          }
        else
          {
            type: 'visitor',
            id: invalid_participant.visitor.id,
            public_id: invalid_participant.visitor.public_id,
            name: invalid_participant.visitor.full_name,
            email: invalid_participant.visitor.email,
            phone: invalid_participant.visitor.phone
          }
        end

        {
          event_type: 'lucky_draw.winner_declared',
          webhook_id: SecureRandom.uuid,
          timestamp: Time.now.utc.iso8601,
          api_version: 'v1',

          event: {
            id: @event.id,
            title: @event.title,
            slug: @event.slug
          },

          lucky_draw_session: {
            id: @session.id,
            title: @session.title,
            draw_date: @session.draw_date&.iso8601
          },

          winner: {
            id: invalid_participant.id,
            drawn_at: invalid_participant.created_at.iso8601,
            participant: participant_data
          }
        }
      end
    end
  end
end