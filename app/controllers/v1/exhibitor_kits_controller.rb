class V1::ExhibitorKitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event
  before_action :set_exhibitor_kit, only: %i[show update]
  before_action :ensure_event_has_exhibitor_kit_enabled, only: %i[index show create update]

  def index
    authorize @event, :show_exhibitor_kits?
    @exhibitor_kits = policy_scope(ExhibitorKit).joins(:event_vendor).where(event_vendors: { event_id: @event.id })
    render json: @exhibitor_kits
  end

  def show
    authorize @exhibitor_kit
    render json: @exhibitor_kit
  end

  def create
    service = ExhibitorKitService.new(user: current_user, event: @event, params: params)
    result = service.create

    if result.success?
      render json: result.data, status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def update
    service = ExhibitorKitService.new(user: current_user, event: @event, params: params)
    result = service.update(@exhibitor_kit)

    if result.success?
      render json: result.data, status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_exhibitor_kit
    @exhibitor_kit = ExhibitorKit.find(params[:id])
    render json: { error: "ExhibitorKit not found for this event" }, status: :not_found unless @exhibitor_kit.event == @event
  end

  def ensure_event_has_exhibitor_kit_enabled
    return if @event.use_exhibitor_kit?

    render json: { error: 'Exhibitor kits are not enabled for this event' }, status: :forbidden
  end
end