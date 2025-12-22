module V1
  class PrintingServicesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_printing_service, only: %i[show update destroy]

    def index
      @printing_services = policy_scope(PrintingService).includes(:item_category)
      render json: @printing_services.map { |service| format_printing_service(service) }
    end

    def show
      authorize @printing_service
      render json: format_printing_service(@printing_service)
    end

    def create
      @printing_service = PrintingService.new(printing_service_params.merge(user: current_user))
      authorize @printing_service

      if @printing_service.save
        render json: format_printing_service(@printing_service), status: :created
      else
        render json: @printing_service.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @printing_service
      handle_image_removal
      if @printing_service.update(printing_service_params)
        render json: format_printing_service(@printing_service)
      else
        render json: @printing_service.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @printing_service
      @printing_service.destroy
      head :no_content
    end

    private

    def set_printing_service
      @printing_service = PrintingService.find(params[:id])
    end

    def printing_service_params
      params.require(:printing_service).permit(:name, :description, :unit_of_measure, :default_price, :status, :item_category_id, :image)
    end

    def handle_image_removal
      if ActiveModel::Type::Boolean.new.cast(params[:remove_image])
        @printing_service.image.purge_later if @printing_service.image.attached?
      end
    end

    def format_printing_service(service)
      service.as_json(include: :item_category).merge(
        image_url: service.image.attached? ? url_for(service.image) : nil
      )
    end
  end
end
