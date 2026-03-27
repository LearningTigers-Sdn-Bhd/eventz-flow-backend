module V1
  class ExhibitorBoothPriceTiersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_exhibitor_booth_price
    before_action :set_exhibitor_booth_price_tier, only: %i[show update destroy]

    def index
      tiers = policy_scope(@exhibitor_booth_price.exhibitor_booth_price_tiers).ordered
      render json: tiers.map { |tier| serialize_tier(tier) }
    end

    def show
      authorize @exhibitor_booth_price_tier
      render json: serialize_tier(@exhibitor_booth_price_tier)
    end

    def create
      tier = @exhibitor_booth_price.exhibitor_booth_price_tiers.new(exhibitor_booth_price_tier_params)
      authorize tier

      if tier.save
        render json: serialize_tier(tier), status: :created
      else
        render json: tier.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_booth_price_tier

      if @exhibitor_booth_price_tier.update(exhibitor_booth_price_tier_params)
        render json: serialize_tier(@exhibitor_booth_price_tier)
      else
        render json: @exhibitor_booth_price_tier.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_booth_price_tier
      @exhibitor_booth_price_tier.destroy
      head :no_content
    end

    private

    def set_exhibitor_booth_price
      @exhibitor_booth_price = ExhibitorBoothPrice.find(params[:exhibitor_booth_price_id])
    end

    def set_exhibitor_booth_price_tier
      @exhibitor_booth_price_tier = @exhibitor_booth_price.exhibitor_booth_price_tiers.find(params[:id])
    end

    def exhibitor_booth_price_tier_params
      params.require(:exhibitor_booth_price_tier).permit(:label, :price, :start_date, :end_date)
    end

    def serialize_tier(tier)
      tier.as_json.merge('active' => tier.active?)
    end
  end
end
