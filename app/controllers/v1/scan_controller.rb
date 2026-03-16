module V1
  class ScanController < ApplicationController
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

      # Fetch recent ticket check-ins scanned by the current user
      tickets = Ticket.where(event_id: authorized_event_ids)
                      .where(checked_in: true)
                      .where(scanned_by_id: current_user.id)
                      .where.not(check_in_at: nil)
                      .includes(:ticket_type, :event, :scanned_by)
                      .order(check_in_at: :desc)
                      .limit(limit)

      # Fetch recent visitor check-ins scanned by the current user
      visitors = Visitor.where(event_id: authorized_event_ids)
                        .where(checked_in: true)
                        .where(scanned_by_id: current_user.id)
                        .where.not(check_in_at: nil)
                        .includes(:event, :scanned_by)
                        .order(check_in_at: :desc)
                        .limit(limit)

      # Combine and sort by check_in_at
      combined = []

      tickets.each do |ticket|
        combined << {
          type: 'ticket',
          scan_id: ticket.public_id,
          role: ticket.role,
          name: ticket.attendee_name,
          email: ticket.attendee_email,
          phone: ticket.attendee_phone,
          ticket_type: ticket.ticket_type&.name,
          ticket_value: ticket.ticket_type&.price.to_f,
          event_id: ticket.event_id,
          event_name: ticket.event&.title,
          checked_in: ticket.checked_in,
          check_in_at: ticket.check_in_at&.iso8601,
          status: 'success',
          scanned_by: ticket.scanned_by ? {
            id: ticket.scanned_by.id,
            full_name: ticket.scanned_by.full_name
          } : nil
        }
      end

      visitors.each do |visitor|
        combined << {
          type: 'visitor',
          scan_id: visitor.public_id,
          role: visitor.role,
          name: visitor.full_name,
          email: visitor.email,
          phone: visitor.phone,
          gender: visitor.gender,
          age: visitor.age,
          event_id: visitor.event_id,
          event_name: visitor.event&.title,
          checked_in: visitor.checked_in,
          check_in_at: visitor.check_in_at&.iso8601,
          status: 'success',
          scanned_by: visitor.scanned_by ? {
            id: visitor.scanned_by.id,
            full_name: visitor.scanned_by.full_name
          } : nil
        }
      end

      # Sort by check_in_at descending and limit
      combined.sort_by! { |r| r[:check_in_at] || '' }
      combined.reverse!
      combined = combined.take(limit)

      render json: {
        check_ins: combined,
        total: combined.size,
        limit: limit
      }, status: :ok
    end

    # PATCH /v1/scan/:public_id/check_in
    # Unified check-in endpoint that handles both tickets and visitors
    def check_in
      public_id = params[:public_id]

      # Try to find as ticket first, then visitor
      @record = find_scannable_record(public_id)

      if @record.nil?
        render json: { error: 'Record not found. Invalid QR code.' }, status: :not_found
        return
      end

      # Determine type and authorize
      @type = @record.is_a?(Ticket) ? 'ticket' : 'visitor'
      authorize @record, :check_in?

      # Check if already checked in
      if @record.checked_in?
        render json: {
          error: "#{@type.capitalize} has already been checked in.",
          type: @type,
          checked_in_at: @record.check_in_at&.iso8601
        }, status: :unprocessable_content
        return
      end

      # Perform check-in
      check_in_params = {
        checked_in: true,
        check_in_at: Time.current,
        scanned_by_id: current_user.id
      }

      # Tickets also need status update
      check_in_params[:status] = :scanned if @record.is_a?(Ticket)

      if @record.update(check_in_params)
        broadcast_to_welcome_screen
        render json: build_response, status: :ok
      else
        render json: @record.errors, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Not authorized to check in this record' }, status: :forbidden
    end

    private

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
        role: @record.role,
        custom_fields_data: @record.custom_fields_data
      )
    end
  end
end
