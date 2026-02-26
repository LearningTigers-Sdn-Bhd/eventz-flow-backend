module V1
  class ExhibitorZoneQuotasController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create]
    before_action :set_exhibitor_zone_quota, only: %i[update destroy]

    def index
      zone_quotas = policy_scope(@event.exhibitor_zone_quotas).order(:zone)
      render json: zone_quotas
    end

    def create
      zone_quota = @event.exhibitor_zone_quotas.new(exhibitor_zone_quota_params)
      authorize zone_quota

      if zone_quota.save
        render json: zone_quota, status: :created
      else
        render json: zone_quota.errors, status: :unprocessable_content
      end
    end

    def update
      authorize @exhibitor_zone_quota

      if @exhibitor_zone_quota.update(exhibitor_zone_quota_params)
        render json: @exhibitor_zone_quota
      else
        render json: @exhibitor_zone_quota.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_zone_quota
      @exhibitor_zone_quota.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_zone_quota
      @exhibitor_zone_quota = ExhibitorZoneQuota.find(params[:id])
    end

    def exhibitor_zone_quota_params
      params.require(:exhibitor_zone_quota).permit(:zone, :quota)
    end
  end
end
