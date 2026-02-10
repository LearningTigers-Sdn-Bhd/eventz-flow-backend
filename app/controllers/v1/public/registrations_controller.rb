# frozen_string_literal: true

module V1
  module Public
    class RegistrationsController < ApplicationController
      # Skip all authentication for public endpoints
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published?
          return render json: {
            success: false,
            message: "Registration is not open for this event"
          }, status: :unprocessable_entity
        end

        ticket_type = event.ticket_types.publicly_available.find(params[:ticket_type_id])

        ticket = event.tickets.new(registration_params)
        ticket.ticket_type = ticket_type
        ticket.payment_status = ticket_type.current_price.zero? ? "paid" : "pending"

        if ticket.save
          render json: {
            success: true,
            data: serialize_ticket(ticket, ticket_type)
          }, status: :created
        else
          render json: {
            success: false,
            errors: ticket.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def ticket_types
        event = Event.friendly.find(params[:event_slug])

        ticket_types = event.ticket_types.publicly_available.map do |tt|
          {
            id: tt.id,
            name: tt.name,
            price: tt.current_price,
            current_tier: tt.active_tier&.label,
            available: tt.quantity.nil? || tt.tickets.count < tt.quantity,
            custom_fields_data: tt.custom_fields_data
          }
        end

        render json: { success: true, data: ticket_types }
      end

      private

      def registration_params
        params.permit(
          :attendee_name,
          :attendee_email,
          :attendee_phone,
          :role,
          custom_fields_data: {}
        )
      end

      def serialize_ticket(ticket, ticket_type)
        {
          ticket_id: ticket.id,
          public_id: ticket.public_id,
          attendee_name: ticket.attendee_name,
          attendee_email: ticket.attendee_email,
          attendee_phone: ticket.attendee_phone,
          role: ticket.role,
          ticket_type: ticket_type.name,
          price: ticket_type.current_price,
          payment_status: ticket.payment_status,
          custom_fields_data: ticket.custom_fields_data,
          qr_code_data: ticket.public_id
        }
      end
    end
  end
end
