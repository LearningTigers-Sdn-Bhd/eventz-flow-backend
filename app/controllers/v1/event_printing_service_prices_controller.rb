module V1
  class EventPrintingServicePricesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_printing_service
    before_action :set_event_printing_service_price_tier, only: %i[show update destroy]

    def index
      @event_printing_service_price_tiers = policy_scope(@event_printing_service.event_printing_service_price_tiers)
      render json: @event_printing_service_price_tiers
    end

    def show
      authorize @event_printing_service_price_tier
      render json: @event_printing_service_price_tier
    end

    def create
      @event_printing_service_price_tier = @event_printing_service.event_printing_service_price_tiers.new(event_printing_service_price_tier_params)
      authorize @event_printing_service_price_tier

      if @event_printing_service_price_tier.save
        render json: @event_printing_service_price_tier, status: :created
      else
        render json: @event_printing_service_price_tier.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @event_printing_service_price_tier
      if @event_printing_service_price_tier.update(event_printing_service_price_tier_params)
        render json: @event_printing_service_price_tier
      else
        render json: @event_printing_service_price_tier.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @event_printing_service_price_tier
      @event_printing_service_price_tier.destroy
      head :no_content
    end

    private

    def set_event_printing_service
      @event_printing_service = EventPrintingService.find(params[:event_printing_service_id])
    end

    def set_event_printing_service_price_tier
      @event_printing_service_price_tier = @event_printing_service.event_printing_service_price_tiers.find(params[:id])
    end

    def event_printing_service_price_tier_params
      params.require(:event_printing_service_price_tier).permit(:price, :start_date, :end_date, :label)
    end
  end
end
