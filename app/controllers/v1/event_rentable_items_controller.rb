module V1
  class EventRentableItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_rentable_item, only: %i[show update destroy]

    def index
      # Apply policy scope and eager load the associated rentable_item and item_category
      @event_rentable_items = policy_scope(EventRentableItem)
                                .where(event_id: @event.id)
                                .includes(rentable_item: [:item_category, :image_attachment, :image_blob])

      render json: @event_rentable_items.map { |eri| format_event_rentable_item(eri) }
    end

    def show
      authorize @event_rentable_item
      render json: @event_rentable_item
    end

    # NOTE: Create action disabled - items are now auto-linked when contractor is assigned to event
    # def create
    #   @event_rentable_item = @event.event_rentable_items.new(event_rentable_item_params)
    #   authorize @event_rentable_item
    #
    #   if @event_rentable_item.save
    #     render json: @event_rentable_item, status: :created
    #   else
    #     render json: { errors: @event_rentable_item.errors.full_messages }, status: :unprocessable_content
    #   end
    # end

    def update
      authorize @event_rentable_item
      if @event_rentable_item.update(event_rentable_item_params)
        render json: @event_rentable_item
      else
        render json: { errors: @event_rentable_item.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @event_rentable_item
      @event_rentable_item.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_rentable_item
      @event_rentable_item = @event.event_rentable_items.find(params[:id])
    end

    def event_rentable_item_params
      params.require(:event_rentable_item).permit(:rentable_item_id)
    end

    def format_event_rentable_item(eri)
      eri.as_json(include: { event_rentable_item_price_tiers: {} }).merge(
        rentable_item: eri.rentable_item ? format_rentable_item(eri.rentable_item) : nil
      )
    end

    def format_rentable_item(item)
      item.as_json(include: :item_category).merge(
        image_url: item.image.attached? ? url_for(item.image) : nil
      )
    end
  end
end
