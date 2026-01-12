module V1
  class EventSponsorshipTiersController < ApplicationController
    before_action :set_event
    before_action :set_tier, only: [:update, :destroy]
    before_action :authorize_tier, only: [:update, :destroy]

    # GET /v1/events/:event_id/event_sponsorship_tiers
    def index
      authorize EventSponsorshipTier
      @tiers = policy_scope(EventSponsorshipTier).where(event: @event).order(sort_order: :asc)
      render json: @tiers
    end

    # POST /v1/events/:event_id/event_sponsorship_tiers
    def create
      authorize EventSponsorshipTier
      
      @tier = @event.event_sponsorship_tiers.new(tier_params)
      
      # Derive group_id if not present
      if @tier.group_id.blank?
        # Try to find a group the user manages. 
        managed_group = Group.visible_to(current_user).first
        @tier.group = managed_group if managed_group
      end
      
      if @tier.save
        render json: @tier, status: :created
      else
        render json: @tier.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/events/:event_id/event_sponsorship_tiers/:id
    def update
      if @tier.update(tier_params)
        render json: @tier
      else
        render json: @tier.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:event_id/event_sponsorship_tiers/:id
    def destroy
      @tier.soft_delete
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_tier
      @tier = @event.event_sponsorship_tiers.find(params[:id])
    end

    def authorize_tier
      authorize @tier
    end

    def tier_params
      params.require(:event_sponsorship_tier).permit(
        :group_id, # Required by schema
        :name,
        :description,
        :sponsorship_type_default,
        :currency_default,
        :suggested_value,
        :capacity,
        :benefits,
        :sort_order
      )
    end
  end
end
