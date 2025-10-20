module V1
  class EventStaffController < ApplicationController
    before_action :authenticate_request!
    before_action :set_event
    before_action :authorize_staff_management! # Org Owner or Manager can manage staff

    # POST /v1/events/:event_id/staff
    def create
      assigned_user = User.find(staff_assignment_params[:user_id])
      
      # Find or initialize to handle updates (e.g., changing team member to admin)
      @assignment = @event.event_assignments.find_or_initialize_by(user: assigned_user)
      @assignment.role = staff_assignment_params[:role]

      if @assignment.save
        render json: @assignment.as_json(only: [:id, :event_id, :user_id, :role]), status: :created
      else
        render json: { error: 'Validation Error', errors: @assignment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:event_id/staff/:user_id
    def destroy
      assigned_user = User.find(params[:user_id])
      
      @assignment = @event.event_assignments.find_by(user: assigned_user)

      if @assignment
        @assignment.destroy
        head :no_content
      else
        render json: { error: 'Not Found', message: 'User is not assigned to this event staff.' }, status: :not_found
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
    end

    def authorize_staff_management!
      # Only Org Owner OR Manager (global roles) can manage event staff
      unless current_user.is_org_owner_or_manager?
        render json: { error: 'Forbidden', message: 'Only an organization owner or manager can manage event staff.' }, status: :forbidden
      end
    end

    def staff_assignment_params
      # Ensure only valid roles for the assignment model are permitted
      valid_roles = EventAssignment.roles.keys
      if params.dig(:staff_assignment, :role).in?(valid_roles)
        params.require(:staff_assignment).permit(:user_id, :role)
      else
        # If role is missing or invalid
        raise ActionController::ParameterMissing, "Invalid or missing 'role' for staff assignment."
      end
    end
  end
end