module V1
  class EventPrintingServicesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_printing_service, only: %i[show update destroy]

    def index
      @event_printing_services = policy_scope(EventPrintingService)
        .where(event_id: @event.id)
        .includes(printing_service: :item_category)
      render json: @event_printing_services, include: { printing_service: { include: :item_category } }
    end

    def show
      authorize @event_printing_service
      render json: @event_printing_service, include: { printing_service: { include: :item_category } }
    end

    def create
      @event_printing_service = @event.event_printing_services.new(event_printing_service_params)
      authorize @event_printing_service

      if @event_printing_service.save
        render json: @event_printing_service, include: { printing_service: { include: :item_category } }, status: :created
      else
        render json: { errors: @event_printing_service.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      authorize @event_printing_service
      if @event_printing_service.update(event_printing_service_params)
        render json: @event_printing_service, include: { printing_service: { include: :item_category } }
      else
        render json: { errors: @event_printing_service.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @event_printing_service
      @event_printing_service.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_printing_service
      @event_printing_service = @event.event_printing_services.find(params[:id])
    end

    def event_printing_service_params
      params.require(:event_printing_service).permit(:printing_service_id)
    end
  end
end
