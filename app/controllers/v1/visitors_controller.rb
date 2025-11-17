module V1
  class VisitorsController < ApplicationController
    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize, except: []

    # Load the specific visitor for actions that require it
    before_action :set_visitor, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/visitors
    def index
      # 1. Scope the visitors based on the authorized events and filter by the current event.
      # policy_scope(Visitor) uses VisitorPolicy::Scope to filter visitors the user can see.
      @visitors = policy_scope(Visitor).where(event: @event)
      # 2. Authorization is handled by the EventPolicy check in set_event_and_authorize.

      render json: @visitors.as_json, status: :ok
    end

    # GET /v1/events/:event_id/visitors/:id
    def show
      # Authorize the specific visitor record against the show? policy
      authorize @visitor
      render json: @visitor.as_json, status: :ok
    end

    # POST /v1/events/:event_id/visitors
    def create
      # Build the visitor using ONLY the strong parameters.
      @visitor = @event.visitors.build(visitor_params)

      # KEEP THIS LINE: Explicitly assign event_id to prevent the mysterious "must exist" error
      # seen in the test environment, even if @event.visitors.build is supposed to do it.
      @visitor.event_id = @event.id

      # Authorization check - authorize the visitor record
      authorize @visitor

      if @visitor.save
        @visitor.reload
        render json: @visitor.as_json, status: :created
      else
        render json: @visitor.errors, status: :unprocessable_content
      end
    end

    def update
      # Authorization check: Can the user (Organizer/Staff) update this visitor?
      authorize @visitor, :update?

      if @visitor.update(visitor_params)
        render json: @visitor.as_json, status: :ok
      else
        render json: @visitor.errors, status: :unprocessable_content
      end
    end

    def destroy
      # Authorization check: Can the user (Organizer/Admin) delete this visitor?
      authorize @visitor, :destroy?

      if @visitor.destroy
        head :no_content
      else
        render json: @visitor.errors, status: :unprocessable_content
      end
    end

    private

    def set_event
      # Allow accessing archived events for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    # Refactored set_event and authorize into one method for clarity and correct execution order.
    # The Pundit check now uses the parent resource (@event) for authorization,
    # preventing the 403 test failure for unauthorized access.
    def set_event_and_authorize
      set_event
      if action_name != 'create'
         authorize @event, :show?
      end
    end

    def set_visitor
      # Prioritize finding by UUID (public_id) for security and external API use
      @visitor = @event.visitors.find_by!(public_id: params[:id])
    rescue ActiveRecord::RecordNotFound
      # Fallback to internal ID if UUID fails (e.g., if staff uses the internal integer ID)
      @visitor = @event.visitors.find_by!(id: params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Visitor not found' }, status: :not_found
    end

    # Strong parameters using Rails 8/modern syntax:
    def visitor_params
      # Fields allowed for creation and general visitor updates.
      allowed_params = [
        :full_name,
        :email,
        :phone,
        :gender,
        :age
      ]

      params.require(:visitor).permit(*allowed_params)
    end
  end
end
