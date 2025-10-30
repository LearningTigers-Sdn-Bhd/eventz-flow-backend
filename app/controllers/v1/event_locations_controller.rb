module V1
  class EventLocationsController < ApplicationController
    # Ensure all actions are authenticated before proceeding
    before_action :authenticate_user!

    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize

    # Load the specific event location for actions that require it
    before_action :set_event_location, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/event_locations
    def index
      @event_locations = @event.event_locations.includes(:members)
      render json: @event_locations.as_json(include: {
        members: { only: [:id, :full_name, :email] }
      }), status: :ok
    end

    # GET /v1/events/:event_id/event_locations/:id
    def show
      render json: @event_location.as_json(include: {
        members: { only: [:id, :full_name, :email] }
      }), status: :ok
    end

    # POST /v1/events/:event_id/event_locations
    def create
      # Authorization check - can the user create event locations for this event?
      authorize @event, :update? # Using update? since only event admins should manage event locations

      @event_location = @event.event_locations.build(event_location_params)

      if @event_location.save
        # Assign members if provided
        assign_members if params[:event_location][:member_ids].present?

        render json: @event_location.as_json(include: {
          members: { only: [:id, :full_name, :email] }
        }), status: :created
      else
        render json: { errors: @event_location.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/event_locations/:id
    def update
      # Authorization check - can the user update event locations for this event?
      authorize @event, :update?

      if @event_location.update(event_location_params)
        # Update members if provided
        # assign_members if params[:event_location][:member_ids].present?

        assign_members if params[:event_location].key?(:member_ids)

        render json: @event_location.as_json(include: {
          members: { only: [:id, :full_name, :email] }
        }), status: :ok
      else
        render json: { errors: @event_location.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/event_locations/:id
    def destroy
      # Authorization check - can the user delete event locations for this event?
      authorize @event, :update?

      @event_location.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_and_authorize
      set_event
      authorize @event, :show? # User must at least be able to view the event
    end

    def set_event_location
      @event_location = @event.event_locations.find(params[:id])
    end

    def event_location_params
      params.require(:event_location).permit(
        :name,
        :scan_limit,
        :is_unlimited
      )
    end

    # Helper method to assign members to the event location
    def assign_members
      member_ids = params[:event_location][:member_ids].reject(&:blank?)

      # Clear existing members
      @event_location.event_location_members.destroy_all

      # Assign new members
      member_ids.each do |member_id|
        user = User.find_by(id: member_id)
        if user
          @event_location.event_location_members.create(member: user)
        end
      end
    end
  end
end
