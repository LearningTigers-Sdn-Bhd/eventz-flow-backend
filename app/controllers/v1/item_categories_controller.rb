module V1
  class ItemCategoriesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_item_category, only: %i[show update destroy]

    def index
      authorize ItemCategory
      @item_categories = policy_scope(ItemCategory)
      render json: @item_categories
    end

    def show
      authorize @item_category
      render json: @item_category
    end

    def create
      @item_category = ItemCategory.new(item_category_params)
      authorize @item_category

      if @item_category.save
        render json: @item_category, status: :created
      else
        render json: { errors: @item_category.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      authorize @item_category
      if @item_category.update(item_category_params)
        render json: @item_category
      else
        render json: { errors: @item_category.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @item_category
      @item_category.destroy
      head :no_content
    end

    private

    def set_item_category
      @item_category = ItemCategory.find(params[:id])
    end

    def item_category_params
      params.require(:item_category).permit(:name, :active)
    end
  end
end
