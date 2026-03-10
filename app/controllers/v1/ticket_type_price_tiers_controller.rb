module V1
  class TicketTypePriceTiersController < ApplicationController
    before_action :set_ticket_type
    before_action :set_price_tier, only: [:show, :update, :destroy]

    def index
      @tiers = @ticket_type.ticket_type_price_tiers.ordered
      render json: {
        success: true,
        data: @tiers.map { |t| serialize_tier(t) }
      }
    end

    def show
      render json: { success: true, data: serialize_tier(@tier) }
    end

    def create
      @tier = @ticket_type.ticket_type_price_tiers.new(tier_params)

      if @tier.save
        render json: { success: true, data: serialize_tier(@tier) }, status: :created
      else
        render json: { success: false, errors: @tier.errors }, status: :unprocessable_entity
      end
    end

    def update
      if @tier.update(tier_params)
        render json: { success: true, data: serialize_tier(@tier) }
      else
        render json: { success: false, errors: @tier.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      @tier.destroy
      render json: { success: true, message: "Price tier deleted" }
    end

    private

    def set_ticket_type
      @ticket_type = TicketType.find(params[:ticket_type_id])
      authorize @ticket_type.event, :update?
    end

    def set_price_tier
      @tier = @ticket_type.ticket_type_price_tiers.find(params[:id])
    end

    def tier_params
      params.permit(:label, :price, :starts_at, :ends_at)
    end

    def serialize_tier(tier)
      {
        id: tier.id,
        label: tier.label,
        price: tier.price,
        starts_at: tier.starts_at,
        ends_at: tier.ends_at,
        active: tier.active?
      }
    end
  end
end
