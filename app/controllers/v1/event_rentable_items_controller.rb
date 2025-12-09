module V1
  class EventRentableItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_rentable_item, only: %i[show update destroy]

    def index
      @event_rentable_items = policy_scope(EventRentableItem).where(event_id: @event.id)
      render json: @event_rentable_items
    end

    def show
      authorize @event_rentable_item
      render json: @event_rentable_item
    end

    def create
      @event_rentable_item = @event.event_rentable_items.new(event_rentable_item_params)
      authorize @event_rentable_item

      if @event_rentable_item.save
        render json: @event_rentable_item, status: :created
      else
        render json: { errors: @event_rentable_item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      authorize @event_rentable_item
      if @event_rentable_item.update(event_rentable_item_params)
        render json: @event_rentable_item
      else
        render json: { errors: @event_rentable_item.errors.full_messages }, status: :unprocessable_entity
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
  end
end
