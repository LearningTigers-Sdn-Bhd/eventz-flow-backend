module V1
  class VisitorsController < ApplicationController
    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize, except: [:global_check_in]

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

    # PATCH /v1/visitors/:public_id/check_in
    # Global check-in endpoint - finds visitor by public_id and checks them in
    def global_check_in
      # 1. Global Lookup (Find the visitor by its UUID)
      @visitor = Visitor.find_by!(public_id: params[:public_id])

      # 2. Authorization (Must authorize against the found visitor's event)
      authorize @visitor, :check_in?

      # 3. Perform Check-in Logic
      if @visitor.checked_in?
        render json: { error: 'Visitor has already been checked in.' }, status: :unprocessable_content and return
      end

      if @visitor.update(checked_in: true, check_in_at: Time.current, scanned_by_id: current_user.id)
        broadcast_to_welcome_screen(@visitor)
        render json: @visitor.as_json(
          include: {
            event: { only: [:id, :title] },
            scanned_by: { only: [:id, :full_name] }
          }
        ), status: :ok
      else
        render json: @visitor.errors, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Visitor not found' }, status: :not_found
    end

    private

    def broadcast_to_welcome_screen(visitor)
      ActionCable.server.broadcast(
        "welcome_screen_event_#{visitor.event_id}",
        { name: visitor.full_name, checked_in_at: Time.current.iso8601 }
      )
    end

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
      # Pre-process custom_fields_data if it's a string (fixing common client/tooling issues)
      if params.dig(:visitor, :custom_fields_data).is_a?(String)
        begin
          json_data = JSON.parse(params[:visitor][:custom_fields_data])
          params[:visitor][:custom_fields_data] = json_data if json_data.is_a?(Hash)
        rescue JSON::ParserError
          # If parsing fails, leave it as is; strictly permitted params will filter it out.
        end
      end

      # Fields allowed for creation and general visitor updates.
      allowed_params = [
        :full_name,
        :email,
        :phone,
        :gender,
        :age,
        :role,
        :skip_webhooks,
        custom_fields_data: {}
      ]

      params.require(:visitor).permit(*allowed_params)
    end
  end
end
