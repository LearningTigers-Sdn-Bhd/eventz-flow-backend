# frozen_string_literal: true

module V1
  module Public
    class TicketsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        event = Event.friendly.find(params[:event_slug])
        ticket = event.tickets.includes(:ticket_type).find_by!(public_id: params[:id])

        render json: {
          success: true,
          data: {
            public_id: ticket.public_id,
            attendee_name: ticket.attendee_name,
            attendee_email: ticket.attendee_email,
            attendee_phone: ticket.attendee_phone,
            role: ticket.role,
            ticket_type: ticket.ticket_type.name,
            price: ticket.ticket_type.current_price,
            event: {
              title: event.title,
              start_date: event.start_date,
              end_date: event.end_date,
              venue_name: event.venue_name,
              logo_url: event.logo_url
            },
            custom_fields_data: ticket.custom_fields_data,
            qr_code_base64: Base64.strict_encode64(QrCodeService.generate_png(ticket.public_id, size: 600))
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Ticket not found' }, status: :not_found
      end
    end
  end
end
