module V1
  class EventPrintingServicesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_printing_service, only: %i[show update destroy]

    def index
      @event_printing_services = policy_scope(EventPrintingService).where(event_id: @event.id)
      render json: @event_printing_services
    end

    def show
      authorize @event_printing_service
      render json: @event_printing_service
    end

    def create
      @event_printing_service = @event.event_printing_services.new(event_printing_service_params)
      authorize @event_printing_service

      if @event_printing_service.save
        render json: @event_printing_service, status: :created
      else
        render json: { errors: @event_printing_service.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      authorize @event_printing_service
      if @event_printing_service.update(event_printing_service_params)
        render json: @event_printing_service
      else
        render json: { errors: @event_printing_service.errors.full_messages }, status: :unprocessable_entity
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
