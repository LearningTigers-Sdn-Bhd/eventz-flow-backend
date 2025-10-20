module V1
  class EventsController < ApplicationController
    # Ensure event is found and authorized before show, update, and destroy.
    # We pass 'except: [:index, :create]' to ensure the before_action runs on the correct set of actions.
    before_action :set_event, only: [:show, :update, :destroy]
    
    # Authorize the event instance *after* it's set
    before_action :authorize_event, only: [:show, :update, :destroy]
    
    # Authorize the class for index/create (Pundit best practice)
    before_action -> { authorize Event, :index? }, only: [:index]
    before_action -> { authorize Event, :create? }, only: [:create]


    # GET /v1/events
    def index
      # FIX: The index action must use Policy_scope, which will combine 
      # the user's assigned_events and staffed_events based on the Policy::Scope logic.
      @events = policy_scope(Event) 
      render json: @events, status: :ok
    end

    # GET /v1/events/:id
    def show
      # @event is set and authorized by before_actions
      render json: @event, status: :ok
    end

    # POST /v1/events
    def create
      # The Event Policy's 'create?' method (checked above) should ensure 
      # only Org_Owners or authorized Managers can reach this point.
      
      # Step 1: Initialize the Event
      @event = Event.new(event_params)
      
      if @event.save
        # Step 2: Explicitly link the current_user as the EventAdmin/Owner
        # This is necessary because the Event model no longer belongs_to :user
        current_user.assigned_event_admins.create!(event: @event)
        
        render json: @event, status: :created
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/events/:id
    def update
      # @event is set and authorized by before_actions
      if @event.update(event_params)
        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:id
    def destroy
      # @event is set and authorized by before_actions
      @event.destroy
      head :no_content
    end

    private

    # DRY principle: Find the event and handle 404
    def set_event
      # Use find_by! to automatically raise ActiveRecord::RecordNotFound, which 
      # the ApplicationController should rescue and convert to a 404 response.
      @event = Event.find_by!(id: params[:id])
    end
    
    # DRY principle: Perform instance authorization
    def authorize_event
        authorize @event
    end


    # Strong parameters for Event resource
    def event_params
      params.require(:event).permit(
        :title, 
        :description, 
        :status, 
        :multiple_scans, 
        :start_date, 
        :end_date, 
        :webhook_url,
        labels_data: {} # Allows JSONB hash updates
      )
    end
  end
end