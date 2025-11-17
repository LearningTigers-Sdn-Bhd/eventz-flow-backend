module V1
  class EventsController < ApplicationController
    # Ensure event is found and authorized before show, update, destroy, force_delete, and restore.
    # We pass 'except: [:index, :create]' to ensure the before_action runs on the correct set of actions.
    before_action :set_event, only: [:show, :update, :destroy, :force_delete, :restore]

    # Authorize the event instance *after* it's set
    before_action :authorize_event, only: [:show, :update, :destroy, :force_delete, :restore]

    # Authorize the class for index/create (Pundit best practice)
    before_action -> { authorize Event, :index? }, only: [:index]
    before_action -> { authorize Event, :create? }, only: [:create]


    # GET /v1/events
    # Query params:
    #   - archived=true: Show only archived (soft-deleted) events
    #   - full=true: Show all events including archived ones
    def index
      # FIX: The index action must use Policy_scope, which will combine
      # the user's assigned_events and staffed_events based on the Policy::Scope logic.
      @events = policy_scope(Event)

      # Apply filtering based on query parameters
      if params[:archived] == 'true'
        # Show only archived events
        @events = @events.only_deleted
      elsif params[:full] == 'true'
        # Show all events including archived
        @events = @events.with_deleted
      end
      # Default: only non-archived events (handled by default_scope)

      render json: @events, status: :ok
    end

    # GET /v1/events/:id
    def show
      # @event is set and authorized by before_actions
      render json: @event, status: :ok
    end

    # POST /v1/events
    def create
      @event = Event.new(event_params.except(:event_admin_id))

      if @event.save
        # Step 2: Assign event admin
        # If event_admin_id is provided, assign that user; otherwise assign current_user
        admin_user = if event_params[:event_admin_id].present?
                      User.find(event_params[:event_admin_id])
                    else
                      current_user
                    end

        admin_user.assigned_event_admins.create!(event: @event)

        render json: @event, status: :created
      else
        render json: @event.errors, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:id
    def update
      # @event is set and authorized by before_actions
      if @event.update(event_params)
        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:id
    def destroy
      # @event is set and authorized by before_actions
      @event.archive
      head :no_content
    end

    # DELETE /v1/events/:id/force_delete
    def force_delete
      # @event is set and authorized by before_actions
      # Force delete requires organizer/admin authorization
      @event.delete
      head :no_content
    end

    # PATCH /v1/events/:id/restore
    def restore
      # @event is set and authorized by before_actions
      # Restore requires organizer/admin authorization
      if @event.restore
        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    # DRY principle: Find the event and handle 404
    def set_event
      # Use find_by! to automatically raise ActiveRecord::RecordNotFound, which
      # the ApplicationController should rescue and convert to a 404 response.
      # For restore and force_delete actions, use unscoped to find soft-deleted events
      if action_name.in?(['restore', 'force_delete'])
        @event = Event.unscoped.find_by!(id: params[:id])
      else
        @event = Event.find_by!(id: params[:id])
      end
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
        :visibility,
        :use_ticket,
        :event_admin_id, # This will make assigned user as the event admin
        labels_data: {} # Allows JSONB hash updates
      )
    end
  end
end
