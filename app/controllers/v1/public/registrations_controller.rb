# frozen_string_literal: true

module V1
  module Public
    class RegistrationsController < ApplicationController
      # Skip all authentication for public endpoints
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def registration_forms
        event = Event.friendly.find(params[:event_slug])
        forms = event.registration_forms.active.order(:position, :created_at)

        render json: {
          success: true,
          data: forms.map { |f|
            {
              slug: f.slug,
              name: f.name,
              description: f.description
            }
          }
        }
      end

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published?
          return render json: {
            success: false,
            message: "Registration is not open for this event"
          }, status: :unprocessable_content
        end

        available_ticket_types = event.ticket_types.publicly_available

        # Filter by form_slug if provided
        if params[:form_slug].present?
          form = event.registration_forms.find_by(slug: params[:form_slug])
          unless form
            return render json: {
              success: false,
              message: "Registration form not found"
            }, status: :not_found
          end

          allowed_ticket_type_ids = form.ticket_type_ids
          unless allowed_ticket_type_ids.include?(params[:ticket_type_id].to_i)
            return render json: {
              success: false,
              message: "Ticket type is not allowed for the selected registration form"
            }, status: :unprocessable_content
          end

          available_ticket_types = available_ticket_types.where(id: allowed_ticket_type_ids)
        end

        ticket_type = available_ticket_types.find(params[:ticket_type_id])

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
          }, status: :unprocessable_content
        end
      end

      def ticket_types
        event = Event.friendly.find(params[:event_slug])

        available_ticket_types = event.ticket_types.publicly_available
        rule_by_ticket_type_id = {}

        # Filter by form_slug if provided
        if params[:form_slug].present?
          form = event.registration_forms.find_by(slug: params[:form_slug])
          unless form
            return render json: {
              success: false,
              message: "Registration form not found"
            }, status: :not_found
          end

          mappings = form.registration_form_ticket_types
            .where(ticket_type_id: available_ticket_types.select(:id))

          rule_by_ticket_type_id = mappings.index_by(&:ticket_type_id)
          available_ticket_types = available_ticket_types.where(id: rule_by_ticket_type_id.keys)
        end

        ticket_types = available_ticket_types.map do |tt|
          rule = rule_by_ticket_type_id[tt.id]

          {
            id: tt.id,
            name: tt.name,
            price: tt.current_price,
            current_tier: tt.active_tier&.label,
            available: tt.quantity.nil? || tt.tickets.count < tt.quantity,
            custom_fields_data: tt.custom_fields_data,
            registration_mode: rule&.registration_mode || 'single',
            min_attendees: rule&.min_attendees || 1,
            max_attendees: rule&.max_attendees
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
