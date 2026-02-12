module SeatTicketing
  class CheckoutService
    attr_reader :session, :params, :errors, :result

    def initialize(session, params)
      @session = session
      @params = params
      @errors = []
      @result = nil
    end

    def call
      return false unless valid_params?
      return false unless checkout_session_valid?
      return false unless seats_valid?

      ActiveRecord::Base.transaction do
        process_checkout
      end

      true
    rescue => e
      Rails.logger.error "CheckoutService Error: #{e.message}"
      Rails.logger.error e.backtrace.join("
")
      @errors << e.message
      false
    end

    private

    def valid_params?
      if visitor_params[:email].blank?
        @errors << "Visitor email is required"
        return false
      end
      if params[:checkout_session_uuid].blank?
        @errors << "checkout_session_uuid is required"
        return false
      end
      if params[:seat_ids].blank?
        @errors << "No seats selected"
        return false
      end
      true
    end

    def checkout_session_valid?
      @checkout_session = EventSeatCheckoutSession.find_by(id: params[:checkout_session_uuid])
      if @checkout_session.nil? || @checkout_session.event_seat_session_id != @session.id
        @errors << "Checkout session not found or invalid"
        return false
      end

      if @checkout_session.expired?
        @errors << "Checkout session expired"
        return false
      end
      true
    end

    def seats_valid?
      @seats = EventTicketSeat
        .joins(event_seat_section: { event_seat_venue: :event_seat_session })
        .where(id: params[:seat_ids], event_seat_sessions: { id: @session.id })
      
      if @seats.count != params[:seat_ids].count
        @errors << "Some seats were not found"
        return false
      end

      # Validate availability
      invalid_seats = @seats.reject do |seat|
        seat.available? || (seat.locked? && seat.locked_by_session_id == params[:checkout_session_uuid])
      end

      if invalid_seats.any?
        @errors << "Some seats are no longer available: #{invalid_seats.map(&:name).join(', ')}"
        return false
      end

      if @session.event.use_ticket?
        @ticket_type_id = params[:ticket_type_id] || @session.event.ticket_types.first&.id
        if @ticket_type_id.blank?
          @errors << "ticket_type_id is required"
          return false
        end
      end

      true
    end

    def process_checkout
      event = @session.event

      # 1. Create/Find Visitor
      @visitor = Visitor.find_or_create_by!(
        event_id: event.id,
        email: visitor_params[:email]
      ) do |v|
        v.full_name = visitor_params[:full_name]
        v.phone = visitor_params[:phone]
      end

      # 2. Conditionally Create Ticket
      if event.use_ticket?
        @ticket = Ticket.create!(
          event_id: event.id,
          ticket_type_id: @ticket_type_id,
          attendee_name: visitor_params[:full_name],
          attendee_email: visitor_params[:email],
          attendee_phone: visitor_params[:phone],
          payment_status: :paid,
          status: :purchased
        )
      end

      # 3. Update Seats
      @seats.each do |seat|
        seat.update!(
          ticket_id: @ticket&.id,
          visitor_id: @visitor.id,
          locked_by_session_id: nil
        )
      end

      # 4. Cleanup
      @checkout_session.destroy

      @result = {
        success: true,
        ticket: @ticket ? @ticket.as_json(include: :ticket_type) : nil,
        visitor: @visitor
      }
    end

    def visitor_params
      @params.require(:visitor).permit(:full_name, :email, :phone)
    end
  end
end
