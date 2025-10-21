module V1
  class TicketsController < ApplicationController
    # Ensure all actions are authenticated before proceeding
    before_action :authenticate_request!
    
    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize, except: [:global_check_in]
    
    # Load the specific ticket for actions that require it (only show, check_in now)
    before_action :set_ticket, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/tickets
    def index
      # 1. Scope the tickets based on the authorized events and filter by the current event.
      # policy_scope(Ticket) uses TicketPolicy::Scope to filter tickets the user can see.
      @tickets = policy_scope(Ticket).where(event: @event).includes(:ticket_type)
      # 2. Authorization is handled by the EventPolicy check in set_event_and_authorize.
      # We skip 'authorize @tickets, :index?' as it's often redundant/misused for collections.
      
      render json: @tickets.as_json(include: { ticket_type: { only: [:id, :name, :price] } }), status: :ok
    end

    # GET /v1/events/:event_id/tickets/:id
    def show
      # Authorize the specific ticket record against the show? policy
      authorize @ticket
      render json: @ticket.as_json(include: { ticket_type: { only: [:id, :name, :price] } }), status: :ok
    end

    # POST /v1/events/:event_id/tickets
    def create
      # Authorization check
      authorize @event, :create_ticket? 

      # Build the ticket using ONLY the strong parameters.
      @ticket = @event.tickets.build(ticket_params)

      # @ticket.user = current_user # Hide this for now
      
      # KEEP THIS LINE: Explicitly assign event_id to prevent the mysterious "must exist" error 
      # seen in the test environment, even if @event.tickets.build is supposed to do it.
      @ticket.event_id = @event.id 

      if @ticket.save
        @ticket.reload
        render json: @ticket.as_json(include: { ticket_type: { only: [:id, :name, :price] } }), status: :created
      else
        render json: @ticket.errors, status: :unprocessable_entity
      end
    end

    def update
      # Authorization check: Can the user (Manager/Staff) update this ticket?
      authorize @ticket, :update?

      if @ticket.update(ticket_params)
        render json: @ticket.as_json(include: { ticket_type: { only: [:id, :name, :price] } }), status: :ok
      else
        render json: @ticket.errors, status: :unprocessable_entity
      end
    end

    def destroy
      # Authorization check: Can the user (Manager/Admin) cancel/refund this ticket?
      authorize @ticket, :destroy?

      # Note: A "delete" often means setting a status like 'canceled' or 'refunded', 
      # rather than destroying the record entirely. We'll implement a soft-delete/cancel here.
      
      if @ticket.update(status: :canceled)
        head :no_content
      else
        # This might fail if the status change is invalid (e.g., trying to cancel a canceled ticket without logic to prevent it).
        render json: @ticket.errors, status: :unprocessable_entity
      end
    end

    def global_check_in
      # 1. Global Lookup (Find the ticket by its UUID)
      @ticket = Ticket.find_by!(public_id: params[:public_id])
      
      # 2. Authorization (Must authorize against the found ticket's event)
      # The user must be staff/manager for @ticket.event
      authorize @ticket, :check_in? 
      
      # 3. Perform Check-in Logic
      if @ticket.checked_in?
        render json: { error: 'Ticket has already been checked in.' }, status: :unprocessable_entity and return
      end

      if @ticket.update(checked_in: true, check_in_at: Time.current, status: :scanned)
        render json: @ticket.as_json(include: { ticket_type: { only: [:id, :name, :price] } }), status: :ok
      else
        render json: @ticket.errors, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Ticket not found' }, status: :not_found
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
      @ticket = @event.tickets.find_by!(public_id: params[:id])
    rescue ActiveRecord::RecordNotFound
      # Fallback to internal ID if UUID fails (e.g., if staff uses the internal integer ID)
      render json: { error: 'Ticket not found' }, status: :not_found
    end

    # 🔑 Strong parameters using Rails 8/modern syntax:
    def ticket_params
      # Fields allowed for creation and general attendee updates.
      allowed_params = [
        :attendee_name, 
        :attendee_email,
        :attendee_phone, 
        :ticket_type_id, 
        custom_fields_data: {}
      ]

      # Add fields often needed for staff/manager updates or specific actions,
      # but ensure the controller logic authorizes these updates (e.g., status/checked_in).
      # We assume the controller handles setting user_id and order_id internally.
      if action_name.in?(['update', 'destroy', 'check_in'])
        allowed_params << :checked_in
        allowed_params << :status
      end

      params.require(:ticket).permit(*allowed_params)
    end
  end
end