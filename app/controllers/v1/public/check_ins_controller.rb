# frozen_string_literal: true

module V1
  module Public
    class CheckInsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      before_action :find_event!

      VALID_METHODS = %w[name email phone scan].freeze

      # GET /v1/public/events/:event_slug/check_in
      # Returns event info for check-in page
      def show
        success_response(data: event_info)
      end

      # POST /v1/public/events/:event_slug/check_in
      # Search or perform check-in
      def create
        validate_search_params!

        if @method == 'scan'
          perform_check_in
        else
          search_attendees
        end
      rescue ArgumentError => e
        error_response(message: e.message, status: :bad_request)
      end

      private

      def find_event!
        @event = Event.friendly.find(params[:event_slug])
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Event not found', status: :not_found)
      end

      def validate_search_params!
        @method = params[:method].to_s.downcase
        @value = params[:value].to_s.strip

        raise ArgumentError, "Invalid method. Use: #{VALID_METHODS.join(', ')}" unless VALID_METHODS.include?(@method)
        raise ArgumentError, 'Value is required' if @value.blank?
      end

      def event_info
        {
          id: @event.id,
          title: @event.title,
          slug: @event.slug,
          use_ticket: @event.use_ticket
        }
      end

      # --- Check-in Logic ---

      def perform_check_in
        attendee = find_attendee_by_public_id

        if attendee.is_a?(Ticket)
          perform_ticket_check_in(attendee)
        else
          perform_visitor_check_in(attendee)
        end
      end

      def find_attendee_by_public_id
        attendee = if @event.use_ticket
                     @event.tickets.find_by(public_id: @value)
                   else
                     @event.visitors.find_by(public_id: @value)
                   end

        raise ActiveRecord::RecordNotFound, 'Attendee not found' if attendee.nil?
        attendee
      end

      def perform_ticket_check_in(ticket)
        # Check if ticket is valid for today
        unless ticket.ticket_type.valid_for_date?(Date.current)
          error_response(
            message: 'Ticket not valid for today',
            errors: {
              reason: 'wrong_day',
              valid_from: ticket.ticket_type.valid_from_date,
              valid_to: ticket.ticket_type.valid_to_date,
              validity_description: ticket.ticket_type.validity_description
            },
            status: :unprocessable_entity
          )
          return
        end

        # Check if already checked in today
        if ticket.checked_in_today?
          existing = ticket.check_in_for(Date.current)
          error_response(
            message: 'Already checked in today',
            errors: {
              reason: 'duplicate_today',
              check_in_at: existing.check_in_at&.iso8601
            },
            status: :unprocessable_entity
          )
          return
        end

        # Store check_in_url in Thread for webhook/printer integration
        Thread.current[:check_in_url] = params[:check_in_url] if params[:check_in_url].present?

        ActiveRecord::Base.transaction do
          # Create check-in record
          check_in = ticket.check_ins.create!(
            check_in_at: Time.current,
            scanned_by: nil # Public check-in has no user
          )

          # Update "pernah" flag (first time only)
          unless ticket.checked_in?
            ticket.update!(checked_in: true, status: :scanned)
          end

          # Broadcast to welcome screen
          WelcomeScreenQueueService.enqueue(@event.id, ticket.attendee_name)

          success_response(data: {
            action: 'checked_in',
            message: 'Successfully checked in.',
            attendee: format_ticket(ticket, check_in)
          })
        end
      rescue ActiveRecord::RecordInvalid => e
        error_response(message: 'Check-in failed', errors: { base: e.message }, status: :unprocessable_entity)
      ensure
        Thread.current[:check_in_url] = nil
      end

      def perform_visitor_check_in(visitor)
        return already_checked_in_error(visitor) if visitor.checked_in?

        # Store check_in_url in Thread for webhook/printer integration
        Thread.current[:check_in_url] = params[:check_in_url] if params[:check_in_url].present?

        result = visitor.update(checked_in: true, check_in_at: Time.current)

        if result
          WelcomeScreenQueueService.enqueue(@event.id, visitor.full_name)
          success_response(data: {
            action: 'checked_in',
            message: 'Successfully checked in.',
            attendee: format_visitor(visitor)
          })
        else
          error_response(message: 'Check-in failed', errors: visitor.errors, status: :unprocessable_entity)
        end
      ensure
        Thread.current[:check_in_url] = nil
      end

      def already_checked_in_error(attendee)
        error_response(
          message: 'Already checked in',
          errors: { check_in_at: attendee.check_in_at&.iso8601 },
          status: :unprocessable_entity
        )
      end

      # --- Search Logic ---

      def search_attendees
        attendees = @event.use_ticket ? search_tickets : search_visitors
        raise ActiveRecord::RecordNotFound, 'No attendees found' if attendees.empty?

        success_response(data: {
          action: 'select',
          message: 'Please select to check in.',
          attendees: attendees.map { |a| format_attendee(a) }
        })
      end

      def search_tickets
        search_attendees_by(
          @event.tickets,
          name_col: 'attendee_name',
          email_col: 'attendee_email',
          phone_col: 'attendee_phone'
        )
      end

      def search_visitors
        search_attendees_by(
          @event.visitors,
          name_col: 'full_name',
          email_col: 'email',
          phone_col: 'phone'
        )
      end

      def search_attendees_by(base, name_col:, email_col:, phone_col:)
        case @method
        when 'name'
          base.where("LOWER(#{name_col}) LIKE ?", "%#{@value.downcase}%")
        when 'email'
          base.where("LOWER(#{email_col}) = ?", @value.downcase)
        when 'phone'
          normalized = @value.gsub(/\D+/, '')
          base.where("REGEXP_REPLACE(#{phone_col}, '[^0-9]', '', 'g') LIKE ?", "%#{normalized}%")
        end.order(created_at: :desc).limit(10)
      end

      # --- Formatting ---

      def format_attendee(attendee)
        is_ticket = attendee.is_a?(Ticket)
        {
          public_id: attendee.public_id,
          name: is_ticket ? attendee.attendee_name : attendee.full_name,
          email: is_ticket ? attendee.attendee_email : attendee.email,
          phone: is_ticket ? attendee.attendee_phone : attendee.phone,
          role: attendee.role,
          type_name: is_ticket ? attendee.ticket_type&.name : nil,
          checked_in: attendee.checked_in,
          checked_in_today: is_ticket ? attendee.checked_in_today? : attendee.checked_in
        }.compact
      end

      def format_ticket(ticket, check_in)
        {
          public_id: ticket.public_id,
          name: ticket.attendee_name,
          email: ticket.attendee_email,
          phone: ticket.attendee_phone,
          role: ticket.role,
          type_name: ticket.ticket_type&.name,
          checked_in: ticket.checked_in,
          check_in_at: check_in.check_in_at&.iso8601
        }.compact
      end

      def format_visitor(visitor)
        {
          public_id: visitor.public_id,
          name: visitor.full_name,
          email: visitor.email,
          phone: visitor.phone,
          role: visitor.role,
          checked_in: visitor.checked_in,
          check_in_at: visitor.check_in_at&.iso8601
        }.compact
      end
    end
  end
end
