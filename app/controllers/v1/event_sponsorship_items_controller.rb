module V1
  class EventSponsorshipItemsController < ApplicationController
    before_action :set_sponsorship
    before_action :set_item, only: [:update, :destroy]
    before_action :authorize_item, only: [:update, :destroy]

    # GET /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items
    def index
      authorize EventSponsorshipItem
      @items = policy_scope(EventSponsorshipItem)
                 .where(event_sponsorship: @sponsorship)
                 .includes(:created_by, :updated_by)
      render json: @items, include: ['created_by', 'updated_by']
    end

    # POST /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items
    def create
      @item = @sponsorship.event_sponsorship_items.new(item_params)
      @item.created_by = current_user
      @item.updated_by = current_user
      authorize @item

      if @item.save
        render json: @item, status: :created
      else
        render json: @item.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items/:id
    def update
      @item.assign_attributes(item_params)
      @item.updated_by = current_user
      
      if @item.save
        render json: @item
      else
        render json: @item.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items/:id
    def destroy
      @item.destroy
      head :no_content
    end

    private

    def set_sponsorship
      @sponsorship = EventSponsorship.find(params[:event_sponsorship_id])
    end

    def set_item
      @item = @sponsorship.event_sponsorship_items.find(params[:id])
    end

    def authorize_item
      authorize @item
    end

    def item_params
      params.require(:event_sponsorship_item).permit(
        :item_type,
        :title,
        :quantity,
        :unit_value,
        :total_value,
        :notes,
        :received
      )
    end
  end
end
