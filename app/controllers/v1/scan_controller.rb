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
      ticket_check_ins = TicketCheckIn.joins(:ticket)
                                       .where(tickets: { event_id: authorized_event_ids })
                                       .where(scanned_by_id: current_user.id)
                                       .includes(ticket: [:ticket_type, :event], scanned_by: [])
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

      ticket_check_ins.each do |check_in|
        ticket = check_in.ticket
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
          check_in_at: check_in.check_in_at&.iso8601,
          status: 'success',
          scanned_by: check_in.scanned_by ? {
            id: check_in.scanned_by.id,
            full_name: check_in.scanned_by.full_name
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

      if @record.is_a?(Ticket)
        perform_ticket_check_in
      else
        perform_visitor_check_in
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

    def perform_ticket_check_in
      # Check if ticket is valid for today
      unless @record.ticket_type.valid_for_date?(Date.current)
        render json: {
          error: "Ticket not valid for today",
          reason: "wrong_day",
          type: @type,
          valid_from: @record.ticket_type.valid_from_date,
          valid_to: @record.ticket_type.valid_to_date,
          validity_description: @record.ticket_type.validity_description
        }, status: :unprocessable_content
        return
      end

      # Check if already checked in today
      if @record.checked_in_today?
        existing = @record.check_in_for(Date.current)
        render json: {
          error: "Already checked in today",
          reason: "duplicate_today",
          type: @type,
          checked_in_at: existing.check_in_at&.iso8601
        }, status: :unprocessable_content
        return
      end

      ActiveRecord::Base.transaction do
        # Create check-in record
        @check_in = @record.check_ins.create!(
          check_in_at: Time.current,
          scanned_by: current_user
        )

        # Update "pernah" flag (first time only)
        unless @record.checked_in?
          @record.update!(checked_in: true, status: :scanned)
        end

        broadcast_to_welcome_screen
        render json: build_ticket_response, status: :ok
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def perform_visitor_check_in
      # Visitors keep the original single check-in logic
      if @record.checked_in?
        render json: {
          error: "Visitor has already been checked in.",
          type: @type,
          checked_in_at: @record.check_in_at&.iso8601
        }, status: :unprocessable_content
        return
      end

      check_in_params = {
        checked_in: true,
        check_in_at: Time.current,
        scanned_by_id: current_user.id
      }

      if @record.update(check_in_params)
        broadcast_to_welcome_screen
        render json: build_visitor_response, status: :ok
      else
        render json: @record.errors, status: :unprocessable_content
      end
    end

    def build_ticket_response
      {
        type: @type,
        public_id: @record.public_id,
        checked_in: @record.checked_in,
        check_in_at: @check_in.check_in_at&.iso8601,
        event: {
          id: @record.event.id,
          title: @record.event.title
        },
        scanned_by: @check_in.scanned_by ? {
          id: @check_in.scanned_by.id,
          full_name: @check_in.scanned_by.full_name
        } : nil,
        id: @record.id,
        role: @record.role,
        attendee_name: @record.attendee_name,
        attendee_email: @record.attendee_email,
        attendee_phone: @record.attendee_phone,
        ticket_type: @record.ticket_type ? {
          id: @record.ticket_type.id,
          name: @record.ticket_type.name,
          price: @record.ticket_type.price.to_f,
          valid_from_date: @record.ticket_type.valid_from_date,
          valid_to_date: @record.ticket_type.valid_to_date
        } : nil
      }.compact
    end

    def build_visitor_response
      {
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
        } : nil,
        id: @record.id,
        role: @record.role,
        full_name: @record.full_name,
        email: @record.email,
        phone: @record.phone,
        gender: @record.gender,
        age: @record.age
      }.compact
    end

    def broadcast_to_welcome_screen
      attendee_name = @record.is_a?(Ticket) ? @record.attendee_name : @record.full_name
      WelcomeScreenQueueService.enqueue(@record.event_id, attendee_name)
    end
  end
end
