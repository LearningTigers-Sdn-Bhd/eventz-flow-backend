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
        return already_checked_in_error(attendee) if attendee.checked_in?

        if check_in_attendee(attendee)
          success_response(data: { action: 'checked_in', message: 'Successfully checked in.', attendee: format_attendee(attendee) })
        else
          error_response(message: 'Check-in failed', errors: attendee.errors, status: :unprocessable_entity)
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

      def check_in_attendee(attendee)
        # Store check_in_url in Thread for webhook/printer integration
        Thread.current[:check_in_url] = params[:check_in_url] if params[:check_in_url].present?

        result = if attendee.is_a?(Ticket)
          attendee.update(checked_in: true, check_in_at: Time.current, status: :scanned)
        else
          attendee.update(checked_in: true, check_in_at: Time.current)
        end

        # Broadcast to welcome screen after successful check-in
        if result
          attendee_name = attendee.is_a?(Ticket) ? attendee.attendee_name : attendee.full_name
          WelcomeScreenQueueService.enqueue(
            @event.id,
            attendee_name,
            role: attendee.role,
            custom_fields_data: attendee.custom_fields_data
          )
        end

        # Clear thread-local variable after update
        Thread.current[:check_in_url] = nil
        result
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
          check_in_at: attendee.check_in_at&.iso8601
        }.compact
      end
    end
  end
end
