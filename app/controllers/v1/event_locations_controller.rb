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
      # Use policy scope to filter locations based on user role (vendors see only their assigned locations)
      @event_locations = policy_scope(@event.event_locations).includes(:members)
      
      render json: @event_locations.map { |location| format_location_response(location) }, 
             status: :ok
    end

    # GET /v1/events/:event_id/event_locations/:id
    def show
      render json: format_location_response(@event_location), status: :ok
    end

    # POST /v1/events/:event_id/event_locations
    def create
      # Authorization check - can the user create event locations for this event?
      authorize @event, :update? # Using update? since only event admins should manage event locations

      @event_location = @event.event_locations.build(event_location_params)

      if @event_location.save
        # Assign members if provided
        assign_members if params[:event_location][:member_ids].present?

        render json: format_location_response(@event_location), status: :created
      else
        render json: { errors: @event_location.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/event_locations/:id
    def update
      # Authorization check - can the user update event locations for this event?
      authorize @event, :update?

      if @event_location.update(event_location_params)
        # Only update members if member_ids is explicitly provided and not nil
        # This prevents accidentally clearing members when updating other location attributes
        if params[:event_location].key?(:member_ids) && !params[:event_location][:member_ids].nil?
          assign_members
        end

        render json: format_location_response(@event_location), status: :ok
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
      # Allow accessing archived events for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    def set_event_and_authorize
      set_event
      authorize @event, :show? # User must at least be able to view the event
    end

    def set_event_location
      @event_location = @event.event_locations.find(params[:id])
    end

    def event_location_params
      # First, get the basic permitted params
      basic_params = params.require(:event_location).permit(
        :name,
        :scan_limit,
        :is_unlimited,
        :floor
      )
      
      # Allow any keys in location_details (dynamic JSONB field)
      if params[:event_location].key?(:location_details) && params[:event_location][:location_details].present?
        # Use permit! to allow all nested keys in location_details
        basic_params[:location_details] = params[:event_location][:location_details].to_unsafe_h
      end
      
      basic_params
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
      
      # Reload associations to get updated members
      @event_location.reload
    end

    # Format location response with separated staff and vendors
    def format_location_response(location)
      # Separate members by role
      all_members = location.members
      
      staff_members = all_members.select { |m| ['org_owner', 'organizer', 'member'].include?(m.role) }
      vendor_members = all_members.select { |m| m.role == 'vendor' }
      
      {
        id: location.id,
        name: location.name,
        scan_limit: location.scan_limit,
        is_unlimited: location.is_unlimited,
        event_id: location.event_id,
        floor: location.floor,
        location_details: location.location_details || {},
        location_display_name: location.location_display_name,
        created_at: location.created_at,
        updated_at: location.updated_at,
        
        # Separated by role
        staff_members: staff_members.map { |m| format_member(m, 'staff') },
        vendors: vendor_members.map { |m| format_member(m, 'vendor') }
      }
    end

    # Format individual member with role information
    def format_member(member, member_type = nil)
      {
        id: member.id,
        full_name: member.full_name,
        email: member.email,
        role: member.role,
        member_type: member_type || (member.role == 'vendor' ? 'vendor' : 'staff')
      }
    end
  end
end
