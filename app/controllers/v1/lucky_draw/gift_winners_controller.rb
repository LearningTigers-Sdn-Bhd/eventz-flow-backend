module V1
  module LuckyDraw
    class GiftWinnersController < ApplicationController
      # Load and authorize the parent event before every action
      before_action :set_event
      before_action :set_session
      before_action :authorize_event
      before_action :set_gift
      before_action :set_winner, only: [:destroy, :notify]

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:gift_id/winners
      def create
        authorize GiftWinner.new(gift: @gift)

        @winner = @gift.gift_winners.build(winner_params.merge(drawn_at: Time.current))

        if @winner.save
          @winner.reload
          # Access associations to trigger loading
          @winner.ticket if @winner.ticket_id
          @winner.visitor if @winner.visitor_id

          # Send webhook notification if webhook_url is configured
          send_winner_webhook(@winner)

          success_response(
            data: format_winner_response(@winner),
            message: 'Success',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@winner),
            status: :unprocessable_content
          )
        end
      end

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:gift_id/winners/bulk
      def bulk
        authorize GiftWinner.new(gift: @gift)

        winners_data = bulk_winner_params[:winners] || []

        if winners_data.empty?
          return error_response(
            message: 'Validation failed',
            errors: [{ message: 'winners array cannot be empty' }],
            status: :unprocessable_content
          )
        end

        winners = []
        errors = []

        ActiveRecord::Base.transaction do
          winners_data.each_with_index do |winner_data, index|
            winner = @gift.gift_winners.build(
              ticket_id: winner_data[:ticket_id],
              visitor_id: winner_data[:visitor_id],
              drawn_at: Time.current
            )

            if winner.save
              winner.reload
              # Access associations to trigger loading
              winner.ticket if winner.ticket_id
              winner.visitor if winner.visitor_id
              winners << winner
            else
              errors << { index: index, errors: winner.errors.full_messages }
              raise ActiveRecord::Rollback
            end
          end
        end

        if errors.any?
          error_response(
            message: 'Validation failed',
            errors: errors,
            status: :unprocessable_content
          )
        else
          # Send webhook notifications for all winners
          winners.each { |winner| send_winner_webhook(winner) }

          success_response(
            data: winners.map { |winner| format_winner_response(winner) },
            message: 'Success',
            status: :created
          )
        end
      end

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:gift_id/winners/:winner_id
      def destroy
        authorize @winner
        @winner.destroy
        head :no_content
      end

      # POST /v1/events/:event_id/lucky_draw/sessions/:session_id/gifts/:gift_id/winners/:winner_id/notify
      def notify
        authorize @winner, :notify?

        webhook_url = @event.webhook_url
        unless webhook_url.present?
          return error_response(
            message: 'No webhook URL configured for this event',
            status: :unprocessable_content
          )
        end

        send_winner_webhook(@winner)

        success_response(
          data: format_winner_response(@winner),
          message: 'Notification sent successfully'
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

      def set_gift
        @gift = @session.gifts.find_by!(id: params[:gift_id])
        raise ActiveRecord::RecordNotFound, 'Gift not found' unless @gift
      end

      def set_winner
        @winner = @gift.gift_winners.find_by!(id: params[:id])
      end

      def winner_params
        params.permit(:ticket_id, :visitor_id)
      end

      def bulk_winner_params
        params.permit(winners: [:ticket_id, :visitor_id])
      end

      def format_winner_response(winner)
        # Get participant name from ticket or visitor
        # Associations should already be loaded, but accessing them will trigger loading if needed
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

      def send_winner_webhook(winner)
        webhook_url = @event.webhook_url
        return unless webhook_url.present?

        payload = build_winner_webhook_payload(winner)
        WebhookSenderJob.perform_later(webhook_url, payload)
      rescue StandardError => e
        # Log error but don't fail the request
        Rails.logger.error "Failed to queue webhook: #{e.message}"
      end

      def build_winner_webhook_payload(winner)
        participant = winner.ticket || winner.visitor
        participant_data = if winner.ticket
          {
            type: 'ticket',
            id: winner.ticket.id,
            public_id: winner.ticket.public_id,
            name: winner.ticket.attendee_name,
            email: winner.ticket.attendee_email,
            phone: winner.ticket.attendee_phone
          }
        else
          {
            type: 'visitor',
            id: winner.visitor.id,
            public_id: winner.visitor.public_id,
            name: winner.visitor.full_name,
            email: winner.visitor.email,
            phone: winner.visitor.phone
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

          gift: {
            id: winner.gift.id,
            name: winner.gift.name,
            order: winner.gift.order,
            winner_counts: winner.gift.winner_counts
          },

          winner: {
            id: winner.id,
            drawn_at: winner.drawn_at.iso8601,
            participant: participant_data
          }
        }
      end
    end
  end
end