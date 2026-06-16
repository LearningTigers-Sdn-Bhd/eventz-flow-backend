# frozen_string_literal: true

module V1
  class TicketApplicationsController < ApplicationController
    before_action :set_event
    before_action :set_ticket
    before_action :set_application

    def approve
      authorize @ticket, :update?

      TicketApplicationReviewService.new(@application, reviewer: current_user).approve!
      render json: ticket_payload, status: :ok
    end

    def reject
      authorize @ticket, :destroy?

      result = TicketApplicationReviewService.new(@application, reviewer: current_user).reject!(reason: params[:reason])
      if result.success?
        render json: ticket_payload, status: :ok
      else
        render json: { error: result.error }, status: :unprocessable_content
      end
    end

    def resend_rsvp
      authorize @ticket, :update?

      result = TicketApplicationReviewService.new(@application, reviewer: current_user).resend_rsvp!
      if result.success?
        render json: ticket_payload, status: :ok
      else
        render json: { error: result.error }, status: :unprocessable_content
      end
    end

    def approve_rsvp
      authorize @ticket, :update?

      result = TicketApplicationReviewService.new(@application, reviewer: current_user).approve_rsvp!
      if result.success?
        render json: ticket_payload, status: :ok
      else
        render json: { error: result.error }, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_ticket
      ticket_identifier = params[:ticket_id] || params[:id]
      @ticket = @event.tickets.find_by!(public_id: ticket_identifier)
    end

    def set_application
      @application = @ticket.ticket_application
      return if @application.present?

      render json: { error: 'Ticket application not found' }, status: :not_found
    end

    def ticket_payload
      @ticket.reload.as_json(
        methods: %i[payment_method transaction_id payment_screenshot_url],
        include: {
          ticket_type: { only: %i[id name price] },
          ticket_application: {
            only: %i[
              review_status
              rsvp_status
              reviewed_at
              rejection_reason
              rsvp_sent_at
              rsvp_confirmed_at
              rsvp_expires_at
            ]
          }
        }
      )
    end
  end
end
