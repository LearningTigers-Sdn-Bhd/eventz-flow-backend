module V1
  class EventSponsorshipsController < ApplicationController
    before_action :set_event
    before_action :set_sponsorship, only: [:show, :update, :destroy]
    before_action :authorize_sponsorship, only: [:show, :update, :destroy]

    # GET /v1/events/:event_id/event_sponsorships
    def index
      authorize EventSponsorship
      @sponsorships = policy_scope(EventSponsorship)
                        .where(event: @event)
                        .includes(:sponsor, :event_sponsorship_tier, :event_sponsorship_payments, :event_sponsorship_attachments)
      
      render json: @sponsorships, include: ['sponsor', 'event_sponsorship_tier']
    end

    # GET /v1/events/:event_id/event_sponsorships/:id
    def show
      render json: @sponsorship, include: ['sponsor', 'event_sponsorship_tier', 'event_sponsorship_payments', 'event_sponsorship_attachments', 'event_sponsorship_items']
    end

    # POST /v1/events/:event_id/event_sponsorships
    def create
      authorize EventSponsorship
      @sponsorship = @event.event_sponsorships.new(sponsorship_params)
      
      # Derive group_id from sponsor if not present
      if @sponsorship.group_id.blank?
        @sponsorship.group = @sponsorship.sponsor&.group || Group.visible_to(current_user).first
      end

      @sponsorship.internal_owner_user = current_user

      if @sponsorship.save
        render json: @sponsorship, status: :created
      else
        render json: @sponsorship.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/events/:event_id/event_sponsorships/:id
    def update
      if @sponsorship.update(sponsorship_params)
        render json: @sponsorship
      else
        render json: @sponsorship.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/events/:event_id/event_sponsorships/:id
    def destroy
      @sponsorship.soft_delete
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_sponsorship
      @sponsorship = @event.event_sponsorships.find(params[:id])
    end

    def authorize_sponsorship
      authorize @sponsorship
    end

    def sponsorship_params
      params.require(:event_sponsorship).permit(
        :group_id, # Required
        :sponsor_id,
        :event_sponsorship_tier_id,
        :title,
        :sponsorship_type,
        :currency,
        :total_sponsor_amount,
        :description,
        :status,
        :contact_name,
        :contact_email,
        :contact_whatsapp,
        :contact_position,
        :confirmed_at,
        :cancelled_at,
        :cancel_reason
      )
    end
  end
end
