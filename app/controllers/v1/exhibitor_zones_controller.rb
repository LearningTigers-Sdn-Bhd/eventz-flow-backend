module V1
  class ExhibitorZonesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create]
    before_action :set_exhibitor_zone, only: %i[update destroy]

    def index
      exhibitor_zones = policy_scope(@event.exhibitor_zones).order(:zone)
      render json: exhibitor_zones
    end

    def create
      exhibitor_zone = @event.exhibitor_zones.new(exhibitor_zone_params)
      authorize exhibitor_zone

      if exhibitor_zone.save
        render json: exhibitor_zone, status: :created
      else
        render json: exhibitor_zone.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_zone

      if @exhibitor_zone.update(exhibitor_zone_params)
        render json: @exhibitor_zone
      else
        render json: @exhibitor_zone.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_zone
      @exhibitor_zone.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_zone
      @exhibitor_zone = ExhibitorZone.find(params[:id])
    end

    def exhibitor_zone_params
      params.require(:exhibitor_zone).permit(:zone, :quota)
    end
  end
end
