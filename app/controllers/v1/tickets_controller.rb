module V1
  class TicketsController < ApplicationController
    # Ensure all actions are authenticated before proceeding
    before_action :authenticate_request!
    
    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize
    
    # Load the specific ticket for actions that require it (only show, check_in now)
    before_action :set_ticket, only: [:show, :check_in]

    # GET /v1/events/:event_id/tickets
    def index
      # 1. Scope the tickets based on the authorized events and filter by the current event.
      # policy_scope(Ticket) uses TicketPolicy::Scope to filter tickets the user can see.
      @tickets = policy_scope(Ticket).where(event: @event)
      # 2. Authorization is handled by the EventPolicy check in set_event_and_authorize.
      # We skip 'authorize @tickets, :index?' as it's often redundant/misused for collections.
      
      render json: @tickets, status: :ok
    end

    # GET /v1/events/:event_id/tickets/:id
    def show
      # Authorize the specific ticket record against the show? policy
      authorize @ticket
      render json: @ticket, status: :ok
    end

    # POST /v1/events/:event_id/tickets
    def create
      # Authorization check
      authorize @event, :create_ticket? 

      # Build the ticket using ONLY the strong parameters.
      @ticket = @event.tickets.build(ticket_params)
      
      # KEEP THIS LINE: Explicitly assign event_id to prevent the mysterious "must exist" error 
      # seen in the test environment, even if @event.tickets.build is supposed to do it.
      @ticket.event_id = @event.id 

      if @ticket.save
        render json: @ticket, status: :created
      else
        render json: @ticket.errors, status: :unprocessable_entity
      end
    end
    # PATCH /v1/events/:event_id/tickets/:id/check_in
    def check_in
      # Authorize the specific ticket record against the check_in? policy
      authorize @ticket, :check_in? # Explicitly use check_in? instead of update? for clarity
      
      if @ticket.checked_in?
        return render json: { error: 'Ticket is already checked in.' }, status: :unprocessable_entity
      end

      # Use a direct update call for clarity
      if @ticket.update(checked_in: true, check_in_at: Time.current, status: :scanned)
        render json: @ticket, status: :ok
      else
        render json: @ticket.errors, status: :unprocessable_entity
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
    
    # Refactored set_event and authorize into one method for clarity and correct execution order.
    # The Pundit check now uses the parent resource (@event) for authorization, 
    # preventing the 403 test failure for unauthorized access.
    # Refactored set_event and authorize into one method for clarity and correct execution order.
    def set_event_and_authorize
      set_event
      if action_name != 'create'
         authorize @event, :show? 
      end

    end

    def set_ticket
      # Prioritize finding by UUID (public_id) for security and external API use
      @ticket = Ticket.find_by!(public_id: params[:id])
    rescue ActiveRecord::RecordNotFound
      # Fallback to internal ID if UUID fails (e.g., if staff uses the internal integer ID)
      @ticket = Ticket.find(params[:id])
    end

    # 🔑 Strong parameters using Rails 8/modern syntax:
    def ticket_params
      params.require(:ticket).permit(
        :attendee_name, 
        :attendee_email, 
        :user_id, 
        :order_id, 
        :ticket_type_id,
        custom_fields_data: {} 
      )
    end
  end
end