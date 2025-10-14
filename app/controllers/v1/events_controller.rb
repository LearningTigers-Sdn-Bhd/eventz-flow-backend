# app/controllers/v1/events_controller.rb

module V1
  class EventsController < ApplicationController
    # Enforces JWT authentication via the ApplicationController before any action
    
    # GET /v1/events
    def index
      # policy_scope uses EventPolicy::Scope to return only events the user is authorized to see
      @events = policy_scope(Event) 
      render json: @events, status: :ok
    end

    # GET /v1/events/:id
    def show
      @event = Event.find(params[:id])
      # authorize raises CustomError::Forbidden if show? returns false
      authorize @event 
      render json: @event, status: :ok
    end

    # POST /v1/events
    def create
      # Authorize against the Event class (only superadmin can create)
      authorize Event
      
      # Build the event, associating it with the current_user (the creator/owner)
      @event = current_user.events.build(event_params)

      if @event.save
        render json: @event, status: :created
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/events/:id
    def update
      @event = Event.find(params[:id])
      # authorize raises CustomError::Forbidden if update? returns false (only owner can update)
      authorize @event 

      if @event.update(event_params)
        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:id
    def destroy
      @event = Event.find(params[:id])
      # authorize raises CustomError::Forbidden if destroy? returns false (only owner can delete)
      authorize @event 
      
      @event.destroy
      head :no_content
    end

    private

    # Strong parameters for Event resource
    def event_params
      params.require(:event).permit(
        :title, 
        :description, 
        :status, 
        :multiple_scans, 
        :start_date, 
        :end_date, 
        :location, 
        :webhook_url, 
        labels_data: {} # Allows JSONB hash updates
      )
    end
  end
end