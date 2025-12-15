module V1
  class ExhibitorTeamMemberLimitsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_exhibitor_team_member_limit, only: [:update, :destroy]

    # GET /v1/events/:event_id/exhibitor_team_member_limit
    def show
      @exhibitor_team_member_limit = @event.exhibitor_team_member_limit
      
      if @exhibitor_team_member_limit.present?
        authorize @exhibitor_team_member_limit
        render json: format_response(@exhibitor_team_member_limit), status: :ok
      else
        # Return 200 with null data when not configured (consistent with event_exhibition_contractors)
        authorize @event, :show?
        render json: { 
          data: nil, 
          message: "Team member limit not configured for this event",
          is_configured: false
        }, status: :ok
      end
    end

    # POST /v1/events/:event_id/exhibitor_team_member_limit
    def create
      @exhibitor_team_member_limit = @event.build_exhibitor_team_member_limit(limit_params)
      authorize @exhibitor_team_member_limit

      if @exhibitor_team_member_limit.save
        render json: format_response(@exhibitor_team_member_limit), status: :created
      else
        render json: { errors: @exhibitor_team_member_limit.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH /v1/events/:event_id/exhibitor_team_member_limit
    def update
      authorize @exhibitor_team_member_limit

      if @exhibitor_team_member_limit.update(limit_params)
        render json: format_response(@exhibitor_team_member_limit), status: :ok
      else
        render json: { errors: @exhibitor_team_member_limit.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/exhibitor_team_member_limit
    def destroy
      authorize @exhibitor_team_member_limit

      @exhibitor_team_member_limit.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_team_member_limit
      @exhibitor_team_member_limit = @event.exhibitor_team_member_limit
      unless @exhibitor_team_member_limit
        render json: { error: 'Team member limit not configured for this event' }, status: :not_found
      end
    end

    def limit_params
      params.require(:exhibitor_team_member_limit).permit(:team_member_limit, :extra_team_member_fee)
    end

    def format_response(limit)
      {
        id: limit.id,
        event_id: limit.event_id,
        team_member_limit: limit.team_member_limit,
        extra_team_member_fee: limit.extra_team_member_fee,
        has_limit: limit.has_limit?,
        charges_extra_fee: limit.charges_extra_fee?,
        is_configured: true,
        created_at: limit.created_at,
        updated_at: limit.updated_at
      }
    end
  end
end

