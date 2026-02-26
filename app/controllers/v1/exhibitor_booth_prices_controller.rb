module V1
  class ExhibitorBoothPricesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create]
    before_action :set_exhibitor_booth_price, only: %i[update destroy]

    def index
      booth_prices = policy_scope(@event.exhibitor_booth_prices)
      render json: booth_prices
    end

    def create
      booth_price = @event.exhibitor_booth_prices.new(exhibitor_booth_price_params)
      authorize booth_price

      if booth_price.save
        render json: booth_price, status: :created
      else
        render json: booth_price.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_booth_price

      if @exhibitor_booth_price.update(exhibitor_booth_price_params)
        render json: @exhibitor_booth_price
      else
        render json: @exhibitor_booth_price.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_booth_price
      @exhibitor_booth_price.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_booth_price
      @exhibitor_booth_price = ExhibitorBoothPrice.find(params[:id])
    end

    def exhibitor_booth_price_params
      params.require(:exhibitor_booth_price).permit(:booth_type, :label, :price)
    end
  end
end
