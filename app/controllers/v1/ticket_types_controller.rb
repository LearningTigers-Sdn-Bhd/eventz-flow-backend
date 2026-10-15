module V1
  # Ticket Types Controller
  # Handles both:
  # 1. Global ticket types (event_id is null) - accessible via /v1/ticket_types
  # 2. Event-specific ticket types - accessible via /v1/events/:event_id/ticket_types
  class TicketTypesController < ApplicationController
    # Ensure all actions are authenticated before proceeding
    before_action :authenticate_user!

    # Load and authorize the parent event if event_id is present
    before_action :set_event_and_authorize, if: :event_scoped?

    # Load the specific ticket type for actions that require it
    before_action :set_ticket_type, only: [:show, :update, :destroy]

    # GET /v1/ticket_types (global)
    # GET /v1/events/:event_id/ticket_types (event-specific)
    def index
      @ticket_types = if event_scoped?
                        @event.ticket_types
                      else
                        TicketType.global
                      end
      render json: @ticket_types, methods: :remaining_quantity, status: :ok
    end

    # GET /v1/ticket_types/:id (global)
    # GET /v1/events/:event_id/ticket_types/:id (event-specific)
    def show
      render json: @ticket_type, methods: :remaining_quantity, status: :ok
    end

    # POST /v1/ticket_types (global)
    # POST /v1/events/:event_id/ticket_types (event-specific)
    def create
      if event_scoped?
        # Event-specific ticket type
        authorize @event, :update? # Only event admins can manage ticket types
        @ticket_type = @event.ticket_types.build(ticket_type_params)
      else
        # Global ticket type - only org_owners can create
        unless current_user.org_owner?
          render json: { error: 'Only admins can create global ticket types' }, status: :forbidden
          return
        end
        @ticket_type = TicketType.new(ticket_type_params)
        @ticket_type.event_id = nil # Ensure it's global
      end

      if @ticket_type.save
        render json: @ticket_type, methods: :remaining_quantity, status: :created
      else
        render json: @ticket_type.errors, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/ticket_types/:id (global)
    # PATCH/PUT /v1/events/:event_id/ticket_types/:id (event-specific)
    def update
      if event_scoped?
        authorize @event, :update?
      else
        unless current_user.org_owner?
          render json: { error: 'Only admins can update global ticket types' }, status: :forbidden
          return
        end
      end

      if @ticket_type.update(ticket_type_params)
        render json: @ticket_type, methods: :remaining_quantity, status: :ok
      else
        render json: @ticket_type.errors, status: :unprocessable_content
      end
    end

    # DELETE /v1/ticket_types/:id (global)
    # DELETE /v1/events/:event_id/ticket_types/:id (event-specific)
    def destroy
      if event_scoped?
        authorize @event, :update?
      else
        unless current_user.org_owner?
          render json: { error: 'Only admins can delete global ticket types' }, status: :forbidden
          return
        end
      end

      # Check for seat ticketing constraints
      if @ticket_type.seat_ticketing_type.present?
        if @ticket_type.st_section?
          return render json: { 
            error: 'Cannot delete the base ticket type for a seat section. Please delete or modify the section in the map editor instead.' 
          }, status: :unprocessable_content
        end
      end

      # Check if there are any tickets sold for this ticket type
      if @ticket_type.tickets.exists?
        render json: { error: 'Cannot delete ticket type with existing tickets' }, status: :unprocessable_content
      else
        cleanup_seat_ticketing_links
        @ticket_type.destroy
        head :no_content
      end
    end

    private

    def cleanup_seat_ticketing_links
      return unless @ticket_type.seat_ticketing_type.present?

      case @ticket_type.seat_ticketing_type.to_sym
      when :st_group
        group = EventSeatGroup.find_by(id: @ticket_type.seat_ticketing_source_id)
        group&.destroy # This will cascade to assignments and should be handled carefully if logic is complex
      when :st_individual
        seat = EventTicketSeat.find_by(id: @ticket_type.seat_ticketing_source_id)
        seat&.update_columns(extra_price: 0, ticket_type_id: seat.event_seat_section.ticket_type_id)
      end
    end

    # Check if this is an event-scoped request
    def event_scoped?
      params[:event_id].present?
    end

    def set_event
      # Allow accessing archived events for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    def set_event_and_authorize
      set_event
      authorize @event, :show? # User must at least be able to view the event
    end

    def set_ticket_type
      if event_scoped?
        @ticket_type = @event.ticket_types.find(params[:id])
      else
        @ticket_type = TicketType.global.find(params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      ticket_type = event_scoped? ? 'Ticket type' : 'Global ticket type'
      render json: { error: "#{ticket_type} not found" }, status: :not_found
    end

    def ticket_type_params
      params.require(:ticket_type).permit(
        :name,
        :price,
        :quantity,
        :max_per_order,
        :sale_starts_at,
        :sale_ends_at,
        :status,
        :hidden,
        custom_fields_data: {}
      )
    end
  end
end
