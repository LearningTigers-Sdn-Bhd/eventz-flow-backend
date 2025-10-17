module V1
  class TicketTypesController < ApplicationController
    # Ensure all actions are authenticated before proceeding
    before_action :authenticate_request!
    
    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize
    
    # Load the specific ticket type for actions that require it
    before_action :set_ticket_type, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/ticket_types
    def index
      @ticket_types = @event.ticket_types
      render json: @ticket_types, status: :ok
    end

    # GET /v1/events/:event_id/ticket_types/:id
    def show
      render json: @ticket_type, status: :ok
    end

    # POST /v1/events/:event_id/ticket_types
    def create
      # Authorization check - can the user create ticket types for this event?
      authorize @event, :update? # Using update? since only event admins should manage ticket types

      @ticket_type = @event.ticket_types.build(ticket_type_params)
      
      if @ticket_type.save
        render json: @ticket_type, status: :created
      else
        render json: @ticket_type.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/events/:event_id/ticket_types/:id
    def update
      # Authorization check - can the user update ticket types for this event?
      authorize @event, :update?

      if @ticket_type.update(ticket_type_params)
        render json: @ticket_type, status: :ok
      else
        render json: @ticket_type.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:event_id/ticket_types/:id
    def destroy
      # Authorization check - can the user delete ticket types for this event?
      authorize @event, :update?
      
      # Check if there are any tickets sold for this ticket type
      if @ticket_type.tickets.exists?
        render json: { error: 'Cannot delete ticket type with existing tickets' }, status: :unprocessable_entity
      else
        @ticket_type.destroy
        head :no_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
    
    def set_event_and_authorize
      set_event
      authorize @event, :show? # User must at least be able to view the event
    end

    def set_ticket_type
      @ticket_type = @event.ticket_types.find(params[:id])
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
