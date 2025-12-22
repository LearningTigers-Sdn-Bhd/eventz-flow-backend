module V1
  class RentableItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_rentable_item, only: %i[show update destroy]

    def index
      @rentable_items = policy_scope(RentableItem).includes(:item_category)
      render json: @rentable_items.map { |item| format_rentable_item(item) }
    end

    def show
      authorize @rentable_item
      render json: format_rentable_item(@rentable_item)
    end

    def create
      @rentable_item = RentableItem.new(rentable_item_params.merge(user: current_user))
      authorize @rentable_item

      if @rentable_item.save
        render json: format_rentable_item(@rentable_item), status: :created
      else
        render json: @rentable_item.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @rentable_item
      handle_image_removal
      if @rentable_item.update(rentable_item_params)
        render json: format_rentable_item(@rentable_item)
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
      params.require(:rentable_item).permit(:name, :description, :unit_of_measure, :default_price, :status, :item_category_id, :image)
    end

    def handle_image_removal
      if ActiveModel::Type::Boolean.new.cast(params[:remove_image])
        @rentable_item.image.purge_later if @rentable_item.image.attached?
      end
    end

    def format_rentable_item(item)
      item.as_json(include: :item_category).merge(
        image_url: item.image.attached? ? url_for(item.image) : nil
      )
    end
  end
end
