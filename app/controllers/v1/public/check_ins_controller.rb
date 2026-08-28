# frozen_string_literal: true

module V1
  module Public
    class CheckInsController < ApplicationController
      include ScannableCheckIn

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      before_action :find_event!
      before_action :softly_identify_scanner

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
          perform_check_in(find_attendee_by_public_id)
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

      # This page is walk-up/no-login by design and must never refuse service.
      # If a staff member happens to be logged in on this device (e.g. a
      # registration counter running the panel session), attribute the scan
      # to them and gate it like any other staff scan. Any failure here
      # (missing header, expired token, no matching session) silently leaves
      # current_user nil — the page keeps working exactly as an anonymous
      # kiosk, as it always has.
      def softly_identify_scanner
        header = request.headers['Authorization']
        return unless header&.start_with?('Bearer ')

        token = header.split(' ').last
        payload = JwtService.decode(token)
        session = UserSession.find_by(jti: payload[:jti], user_id: payload[:user_id])
        @current_user = session.user if session&.active?
      rescue StandardError
        nil
      end

      def event_info
        {
          id: @event.id,
          title: @event.title,
          slug: @event.slug,
          use_ticket: @event.use_ticket,
          poster_url: @event.poster_url
        }
      end

      # --- Check-in Logic ---

      def perform_check_in(attendee)
        Thread.current[:check_in_url] = params[:check_in_url] if params[:check_in_url].present?

        status, log = ScanGate.record!(
          attendee,
          by: current_user,
          source: :kiosk,
          location: scan_location_for(attendee.event)
        )

        if status == :blocked
          # This controller's established envelope is success/message/errors
          # (unlike the other four scan endpoints, which render raw hashes) —
          # nest the same blocked_by detail those endpoints expose inside
          # errors, via the shared helper, rather than inventing a new shape.
          return error_response(
            message: 'Already checked in',
            errors: {
              check_in_at: log.scanned_at&.iso8601,
              blocked_by: scan_blocked_payload(log)[:blocked_by]
            },
            status: :unprocessable_content
          )
        end

        success_response(data: {
          action: 'checked_in',
          message: 'Successfully checked in.',
          attendee: format_attendee(attendee.reload)
        })
      ensure
        Thread.current[:check_in_url] = nil
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
