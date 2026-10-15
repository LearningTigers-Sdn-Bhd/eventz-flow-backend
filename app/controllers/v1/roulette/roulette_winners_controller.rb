module V1
  module Roulette
    class RouletteWinnersController < ApplicationController
      before_action :set_event
      before_action :set_session
      before_action :set_winner, only: [:destroy, :notify]

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
          ticket = Ticket.where(event_id: @event.id).find_by(public_id: ticket_public_id)
          unless ticket
            return error_response(
              message: 'Ticket not found',
              status: :not_found
            )
          end
        else
          visitor = Visitor.where(event_id: @event.id).find_by(public_id: visitor_public_id)
          unless visitor
            return error_response(
              message: 'Visitor not found',
              status: :not_found
            )
          end
        end

        # Exhibitors may only draw winners from their own captured leads
        if current_user.exhibitor_for?(@event) && !within_own_leads?(ticket&.id, visitor&.id)
          return error_response(
            message: 'Winner must be drawn from your own captured leads',
            status: :unprocessable_content
          )
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

        # Send webhook notification if webhook_url is configured
        send_winner_webhook(@winner.reload)

        success_response(
          data: format_winner_response(@winner),
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

      # POST /v1/events/:event_id/roulette/sessions/:session_id/winners/:id/notify
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
        @event = Event.friendly.find(params[:event_id])
      end

      def set_session
        @session = @event.roulette_sessions.find(params[:session_id])
      end

      def set_winner
        @winner = @session.roulette_winners.find(params[:id])
      end

      # Exhibitors may only record winners from tickets/visitors they've captured as leads
      def within_own_leads?(ticket_id, visitor_id)
        return true if ticket_id.blank? && visitor_id.blank?

        own_vendor = EventVendor.find_by(event_id: @event.id, vendor_id: current_user.id)
        return false unless own_vendor

        leadable_type = ticket_id.present? ? 'Ticket' : 'Visitor'
        leadable_id = ticket_id.presence || visitor_id
        EventLead.exists?(event_vendor_id: own_vendor.id, leadable_type: leadable_type, leadable_id: leadable_id)
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

      def send_winner_webhook(winner)
        return unless @event.webhook_url.present?

        payload = build_winner_webhook_payload(winner)
        @event.webhook_urls.each do |url|
          WebhookSenderJob.perform_later(url, payload)
        end
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
          event_type: 'roulette.winner_declared',
          webhook_id: SecureRandom.uuid,
          timestamp: Time.now.utc.iso8601,
          api_version: 'v1',

          event: {
            id: @event.id,
            title: @event.title,
            slug: @event.slug
          },

          roulette_session: {
            id: @session.id,
            title: @session.title,
            draw_date: @session.draw_date&.iso8601
          },

          prize: {
            id: winner.roulette_prize.id,
            name: winner.roulette_prize.name,
            quantity: winner.roulette_prize.quantity,
            remaining_quantity: winner.roulette_prize.remaining_quantity
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
