module V1
  class RentableItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_rentable_item, only: %i[show update destroy]

    def index
      @rentable_items = policy_scope(RentableItem).includes(:item_category)
      render json: @rentable_items, include: :item_category
    end

    def show
      authorize @rentable_item
      render json: @rentable_item, include: :item_category
    end

    def create
      @rentable_item = RentableItem.new(rentable_item_params.merge(user: current_user))
      authorize @rentable_item

      if @rentable_item.save
        render json: @rentable_item, include: :item_category, status: :created
      else
        render json: @rentable_item.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @rentable_item
      if @rentable_item.update(rentable_item_params)
        render json: @rentable_item, include: :item_category
      else
        render json: @rentable_item.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @rentable_item
      @rentable_item.destroy
      head :no_content
    end

    private

    def set_rentable_item
      @rentable_item = RentableItem.find(params[:id])
    end

    def rentable_item_params
      params.require(:rentable_item).permit(:name, :description, :unit_of_measure, :default_price, :status, :item_category_id)
    end
  end
end
