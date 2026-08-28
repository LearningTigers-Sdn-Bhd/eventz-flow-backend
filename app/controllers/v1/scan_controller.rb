module V1
  class ScanController < ApplicationController
    include ScannableCheckIn

    # GET /v1/scan/recent_check_ins
    # Returns recent check-ins (both tickets and visitors) scanned by the current user
    # Query params:
    #   - event_id: Filter by specific event (optional)
    #   - limit: Number of records to return (default: 50, max: 100)
    def recent_check_ins
      limit = [[params[:limit].to_i, 1].max, 100].min
      limit = 50 if params[:limit].blank?

      # Get events the user has access to
      authorized_event_ids = policy_scope(Event).pluck(:id)

      # Filter by specific event if provided
      if params[:event_id].present?
        event_id = params[:event_id].to_i
        unless authorized_event_ids.include?(event_id)
          render json: { error: 'Not authorized to view this event' }, status: :forbidden
          return
        end
        authorized_event_ids = [event_id]
      end

      # Scoped to the current user's own scans, per the endpoint's contract
      # (docstring above, and its frontend consumer: a scanning device's own
      # session history). Without this, one staff member's scanner would show
      # every staff member's scans mixed together.
      logs = ScanLog
             .where(event_id: authorized_event_ids, scanned_by_id: current_user.id)
             .includes(:scannable, :event, :event_location, :scanned_by)
             .order(scanned_at: :desc)
             .limit(limit)

      combined = logs.map { |log| build_recent_check_in_response(log) }

      render json: {
        check_ins: combined,
        total: combined.size,
        limit: limit
      }, status: :ok
    end

    # PATCH /v1/scan/:public_id/check_in
    # Unified check-in endpoint that handles both tickets and visitors
    def check_in
      @record = find_scannable_record(params[:public_id])

      if @record.nil?
        render json: { error: 'Record not found. Invalid QR code.' }, status: :not_found
        return
      end

      # Determine type and authorize
      @type = @record.is_a?(Ticket) ? 'ticket' : 'visitor'
      authorize @record, :check_in?

      status, log = ScanGate.record!(
        @record,
        by: current_user,
        source: :staff_scan,
        location: scan_location_for(@record.event)
      )

      if status == :blocked
        render json: scan_blocked_payload(
          log, message: "#{@type.capitalize} has already been checked in."
        ).merge(type: @type), status: :unprocessable_content
        return
      end

      @record.reload
      broadcast_to_welcome_screen
      render json: build_response, status: :ok
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Not authorized to check in this record' }, status: :forbidden
    end

    private

    def build_recent_check_in_response(log)
      record = log.scannable
      scanned_by = log.scanned_by ? {
        id: log.scanned_by.id,
        full_name: log.scanned_by.full_name
      } : nil

      base_response = {
        scan_id: record.public_id,
        role: record.role,
        email: record.is_a?(Ticket) ? record.attendee_email : record.email,
        phone: record.is_a?(Ticket) ? record.attendee_phone : record.phone,
        event_id: record.event_id,
        event_name: log.event&.title,
        checked_in: record.checked_in,
        check_in_at: log.scanned_at&.iso8601,
        status: 'success',
        scanned_by: scanned_by
      }

      if record.is_a?(Ticket)
        base_response.merge(
          type: 'ticket',
          name: record.attendee_name,
          ticket_type: record.ticket_type&.name,
          ticket_value: record.ticket_type&.price.to_f
        )
      else
        base_response.merge(
          type: 'visitor',
          name: record.full_name,
          gender: record.gender,
          age: record.age
        )
      end
    end

    # Find either a ticket or visitor by public_id
    def find_scannable_record(public_id)
      # Try ticket first (more common use case)
      ticket = Ticket.find_by(public_id: public_id)
      return ticket if ticket.present?

      # Try visitor
      visitor = Visitor.find_by(public_id: public_id)
      return visitor if visitor.present?

      nil
    end

    # Build unified response based on record type
    def build_response
      base_response = {
        type: @type,
        public_id: @record.public_id,
        checked_in: @record.checked_in,
        check_in_at: @record.check_in_at&.iso8601,
        event: {
          id: @record.event.id,
          title: @record.event.title
        },
        scanned_by: @record.scanned_by ? {
          id: @record.scanned_by.id,
          full_name: @record.scanned_by.full_name
        } : nil
      }

      if @record.is_a?(Ticket)
        base_response.merge!(
          id: @record.id,
          role: @record.role,
          attendee_name: @record.attendee_name,
          attendee_email: @record.attendee_email,
          attendee_phone: @record.attendee_phone,
          ticket_type: @record.ticket_type ? {
            id: @record.ticket_type.id,
            name: @record.ticket_type.name,
            price: @record.ticket_type.price.to_f
          } : nil
        )
      else
        # Visitor
        base_response.merge!(
          id: @record.id,
          role: @record.role,
          full_name: @record.full_name,
          email: @record.email,
          phone: @record.phone,
          gender: @record.gender,
          age: @record.age
        )
      end

      base_response.compact
    end

    def broadcast_to_welcome_screen
      attendee_name = @record.is_a?(Ticket) ? @record.attendee_name : @record.full_name
      WelcomeScreenQueueService.enqueue(
        @record.event_id,
        attendee_name,
        custom_fields_data: @record.custom_fields_data
      )
    end
  end
end
