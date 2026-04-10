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
          data: forms.map do |f|
            {
              slug: f.slug,
              name: f.name,
              description: f.description,
              custom_labels_data: f.custom_labels_data || []
            }
          end
        }
      end

      def registration_status
        event = Event.friendly.find(params[:event_slug])
        email = params[:email].to_s.strip.downcase
        form_slug = params[:form_slug].to_s.strip

        if email.blank?
          return render json: {
            success: false,
            message: 'Email is required'
          }, status: :unprocessable_content
        end

        tickets = event.tickets.where(
          'LOWER(attendee_email) = :email OR LOWER(registered_by_email) = :email',
          email: email
        )
        if form_slug.present?
          form = event.registration_forms.find_by(slug: form_slug)
          tickets = tickets.where(ticket_type_id: registration_status_ticket_type_ids(event:, form:)) if form
        end

        upgrade_ticket = conference_upgrade_ticket(event:, email:, form_slug:)
        blocked_upgrade_ticket = blocked_conference_upgrade_ticket(event:, email:, form_slug:)

        pending_tickets = tickets
                          .where(status: :pending_payment, payment_status: %i[pending failed])
                          .includes(:ticket_type)
                          .order(created_at: :desc)

        paid_tickets = tickets
                       .where(payment_status: :paid)
                       .where.not(status: %i[canceled refunded])
                       .includes(:ticket_type)
                       .order(created_at: :desc)

        render json: {
          success: true,
          data: {
            has_pending_payment: pending_tickets.exists?,
            has_paid_ticket: paid_tickets.exists?,
            pending_tickets: pending_tickets.limit(5).map do |ticket|
              serialize_status_ticket(ticket)
            end,
            paid_tickets: paid_tickets.limit(5).map do |ticket|
              serialize_status_ticket(ticket)
            end,
            upgrade_mode: upgrade_ticket.present?,
            upgrade_target: upgrade_ticket.present? ? 'conference' : nil,
            existing_ticket_public_id: upgrade_ticket&.public_id,
            existing_attendee_name: upgrade_ticket&.attendee_name,
            existing_attendee_email: upgrade_ticket&.attendee_email,
            existing_attendee_phone: upgrade_ticket&.attendee_phone,
            existing_ticket_type: upgrade_ticket&.ticket_type&.name,
            blocked_exhibitor_upgrade: blocked_upgrade_ticket.present?,
            blocked_reason: blocked_upgrade_ticket.present? ? 'unpaid_exhibitor' : nil,
            blocked_message: blocked_upgrade_ticket.present? ? 'You already have an unpaid exhibitor registration. Please complete that payment first before registering for conference.' : nil
          }
        }
      end

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published?
          return render json: {
            success: false,
            message: 'Registration is not open for this event'
          }, status: :unprocessable_content
        end

        available_ticket_types = event.ticket_types.publicly_available

        # Filter by form_slug if provided
        if params[:form_slug].present?
          form = event.registration_forms.find_by(slug: params[:form_slug])
          unless form
            return render json: {
              success: false,
              message: 'Registration form not found'
            }, status: :not_found
          end

          allowed_ticket_type_ids = form.ticket_type_ids
          unless allowed_ticket_type_ids.include?(params[:ticket_type_id].to_i)
            return render json: {
              success: false,
              message: 'Ticket type is not allowed for the selected registration form'
            }, status: :unprocessable_content
          end

          available_ticket_types = available_ticket_types.where(id: allowed_ticket_type_ids)
        end

        ticket_type = available_ticket_types.find(params[:ticket_type_id])

        ticket = conference_upgrade_ticket(
          event: event,
          email: registration_params[:attendee_email],
          form_slug: params[:form_slug]
        )

        if ticket
          return render json: {
            success: true,
            data: serialize_ticket(ticket, ticket_type)
          }, status: :created
        else
          ticket = event.tickets.new(registration_params)
          ticket.ticket_type = ticket_type

          if auto_paid_ticket?(event: event, ticket: ticket, ticket_type: ticket_type)
            ticket.status = 'purchased'
            ticket.payment_status = 'paid'
          else
            ticket.status = 'pending_payment'
            ticket.payment_status = 'pending'
          end
        end

        if ticket.save
          render json: {
            success: true,
            data: serialize_ticket(ticket, ticket.ticket_type)
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
              message: 'Registration form not found'
            }, status: :not_found
          end

          mappings = form.registration_form_ticket_types
                         .where(ticket_type_id: available_ticket_types.select(:id))

          rule_by_ticket_type_id = mappings.index_by(&:ticket_type_id)
          available_ticket_types = available_ticket_types.where(id: rule_by_ticket_type_id.keys)
        end

        ticket_types = available_ticket_types.map do |tt|
          rule = rule_by_ticket_type_id[tt.id]
          sold_count = tt.tickets.where(payment_status: :paid).where.not(status: %i[canceled refunded]).count

          {
            id: tt.id,
            name: tt.name,
            price: tt.current_price,
            original_price: tt.price,
            current_tier: tt.active_tier&.label,
            available: tt.quantity.nil? || sold_count < tt.quantity,
            remaining_slots: tt.quantity.nil? ? nil : [tt.quantity - sold_count, 0].max,
            custom_fields_data: tt.custom_fields_data,
            custom_labels_data: rule&.custom_labels_data || [],
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
          :registered_by_email,
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

      def serialize_status_ticket(ticket)
        {
          public_id: ticket.public_id,
          attendee_name: ticket.attendee_name,
          attendee_email: ticket.attendee_email,
          registered_by_email: ticket.registered_by_email,
          attendee_phone: ticket.attendee_phone,
          ticket_type: ticket.ticket_type&.name,
          ticket_type_id: ticket.ticket_type_id,
          price: ticket.ticket_type&.current_price || 0,
          payment_status: ticket.payment_status,
          status: ticket.status,
          custom_fields_data: ticket.custom_fields_data || {},
          qr_code_data: ticket.public_id
        }
      end

      def registration_status_ticket_type_ids(event:, form:)
        ticket_type_ids = form.ticket_type_ids

        return ticket_type_ids unless borneo_conference_form?(event:, form:)

        ticket_type_ids + borneo_combined_ticket_type_ids(event) + borneo_exhibitor_only_ticket_type_ids(event)
      end

      def conference_upgrade_ticket(event:, email:, form_slug:)
        conference_upgrade_source_ticket(
          event: event,
          email: email,
          form_slug: form_slug,
          payment_status: :paid,
          status: :purchased
        )
      end

      def blocked_conference_upgrade_ticket(event:, email:, form_slug:)
        conference_upgrade_source_ticket(
          event: event,
          email: email,
          form_slug: form_slug,
          payment_status: %i[pending failed],
          status: :pending_payment
        )
      end

      def conference_upgrade_source_ticket(event:, email:, form_slug:, payment_status:, status:)
        return unless borneo_event_slug?(event)
        return unless conference_like_form_slug?(form_slug)

        normalized_email = email.to_s.strip.downcase
        return if normalized_email.blank?

        event.tickets
             .where(attendee_email_norm: normalized_email)
             .where(payment_status: payment_status, status: status)
             .where.not(status: %i[canceled refunded])
             .includes(:ticket_type)
             .order(:id)
             .find { |ticket| exhibitor_only_ticket_type?(ticket.ticket_type) }
      end

      def borneo_conference_form?(event:, form:)
        borneo_event_slug?(event) && conference_like_form_slug?(form.slug)
      end

      def borneo_combined_ticket_type_ids(event)
        event.ticket_types.select { |ticket_type| borneo_combined_ticket_type?(ticket_type) }.map(&:id)
      end

      def borneo_exhibitor_only_ticket_type_ids(event)
        event.ticket_types.select { |ticket_type| exhibitor_only_ticket_type?(ticket_type) }.map(&:id)
      end

      def borneo_combined_ticket?(event:, ticket:)
        borneo_event_slug?(event) && borneo_combined_ticket_type?(ticket.ticket_type)
      end

      def borneo_combined_ticket_type?(ticket_type)
        name = ticket_type&.name.to_s.downcase
        name.include?('exhibitor') && (name.include?('conference') || name.include?('delegate'))
      end

      def exhibitor_only_ticket_type?(ticket_type)
        name = ticket_type&.name.to_s.downcase
        name.include?('exhibitor') && !conference_like_form_slug?(name)
      end

      def conference_like_form_slug?(value)
        slug = value.to_s.strip.downcase
        return false if slug.blank?

        slug.include?('conference') || slug.include?('delegate')
      end

      def borneo_event_slug?(event)
        event.slug.to_s.strip.downcase.start_with?(BorneoExpoTicketUpgradeService::BORNEO_EVENT_SLUG_PREFIX)
      end

      def auto_paid_ticket?(event:, ticket:, ticket_type:)
        return false unless ticket_type.current_price.zero?
        return true if ticket.registered_by_email.blank?

        leader_email = ticket.registered_by_email.to_s.strip.downcase
        return false if leader_email.blank?

        event.tickets
             .where(payment_status: :paid, status: :purchased)
             .where('LOWER(attendee_email) = ? OR LOWER(registered_by_email) = ?', leader_email, leader_email)
             .exists?
      end
    end
  end
end
