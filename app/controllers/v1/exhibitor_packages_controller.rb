module V1
  class ExhibitorPackagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create]
    before_action :set_exhibitor_package, only: %i[update destroy]

    def index
      packages = policy_scope(@event.exhibitor_packages.includes(:exhibitor_booth_price))
      render json: packages.map { |package| serialize_package(package) }
    end

    def create
      package = @event.exhibitor_packages.new(exhibitor_package_params)
      authorize package

      if package.save
        render json: serialize_package(package), status: :created
      else
        render json: package.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_package

      if @exhibitor_package.update(exhibitor_package_params)
        render json: serialize_package(@exhibitor_package)
      else
        render json: @exhibitor_package.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_package

      if @exhibitor_package.destroy
        head :no_content
      else
        render json: @exhibitor_package.errors, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_package
      @exhibitor_package = ExhibitorPackage.find(params[:id])
    end

    def exhibitor_package_params
      params.require(:exhibitor_package).permit(:exhibitor_booth_price_id, :name, :inclusions, :price, :quota)
    end

    def serialize_package(package)
      package.as_json.merge(
        'booth_price_label' => package.exhibitor_booth_price&.label,
        'booth_price_zone' => package.exhibitor_booth_price&.zone,
        'booth_price_booth_type' => package.exhibitor_booth_price&.booth_type
      )
    end
  end
end
