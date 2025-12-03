module V1
  class EventRentableItemPricesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_rentable_item
    before_action :set_event_rentable_item_price_tier, only: %i[show update destroy]

    def index
      @event_rentable_item_price_tiers = policy_scope(@event_rentable_item.event_rentable_item_price_tiers)
      render json: @event_rentable_item_price_tiers
    end

    def show
      authorize @event_rentable_item_price_tier
      render json: @event_rentable_item_price_tier
    end

    def create
      @event_rentable_item_price_tier = @event_rentable_item.event_rentable_item_price_tiers.new(event_rentable_item_price_tier_params)
      authorize @event_rentable_item_price_tier

      if @event_rentable_item_price_tier.save
        render json: @event_rentable_item_price_tier, status: :created
      else
        render json: @event_rentable_item_price_tier.errors, status: :unprocessable_entity
      end
    end

    def update
      authorize @event_rentable_item_price_tier
      if @event_rentable_item_price_tier.update(event_rentable_item_price_tier_params)
        render json: @event_rentable_item_price_tier
      else
        render json: @event_rentable_item_price_tier.errors, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @event_rentable_item_price_tier
      @event_rentable_item_price_tier.destroy
      head :no_content
    end

    private

    def set_event_rentable_item
      @event_rentable_item = EventRentableItem.find(params[:event_rentable_item_id])
    end

    def set_event_rentable_item_price_tier
      @event_rentable_item_price_tier = @event_rentable_item.event_rentable_item_price_tiers.find(params[:id])
    end

    def event_rentable_item_price_tier_params
      params.require(:event_rentable_item_price_tier).permit(:price, :start_date, :end_date, :label)
    end
  end
end
