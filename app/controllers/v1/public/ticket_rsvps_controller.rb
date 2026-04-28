# frozen_string_literal: true

module V1
  module Public
    class TicketRsvpsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        render json: { success: true, data: payload }, status: :ok
      end

      def confirm
        result = TicketApplicationReviewService.new(application).confirm_rsvp!(raw_token: params[:token])
        if result.success?
          render json: { success: true, data: payload }, status: :ok
        else
          render json: { success: false, message: result.error, data: payload }, status: :unprocessable_content
        end
      end

      def decline
        result = TicketApplicationReviewService.new(application).decline_rsvp!(raw_token: params[:token])
        if result.success?
          render json: { success: true, data: payload }, status: :ok
        else
          render json: { success: false, message: result.error, data: payload }, status: :unprocessable_content
        end
      end

      private

      def event
        @event ||= Event.friendly.find(params[:event_slug])
      end

      def application
        @application ||= TicketApplication
                         .includes(ticket: :event)
                         .joins(:ticket)
                         .where(tickets: { event_id: event.id })
                         .find_by!(rsvp_token_digest: TicketApplication.digest_token(params[:token]))
      end

      def ticket
        application.ticket
      end

      def payload
        {
          attendee_name: ticket.attendee_name,
          attendee_email: ticket.attendee_email,
          attendee_phone: ticket.attendee_phone,
          event_title: event.title,
          review_status: application.review_status,
          rsvp_status: application.rsvp_status,
          rsvp_expires_at: application.rsvp_expires_at&.iso8601,
          ticket_status: ticket.status,
          payment_status: ticket.payment_status
        }
      end
    end
  end
end
