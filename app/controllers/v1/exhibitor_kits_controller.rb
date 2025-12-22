class V1::ExhibitorKitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event
  before_action :set_exhibitor_kit, only: %i[show update submit_order]
  before_action :ensure_event_has_exhibitor_kit_enabled, only: %i[index show create update submit_order]

  def index
    authorize @event, :show_exhibitor_kits?
    @exhibitor_kits = policy_scope(ExhibitorKit).joins(:event_vendor).where(event_vendors: { event_id: @event.id })
    render json: @exhibitor_kits
  end

  def show
    authorize @exhibitor_kit
    render json: format_exhibitor_kit(@exhibitor_kit)
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

  def submit_order
    authorize @exhibitor_kit, :update?

    service = ExhibitorKitSubmissionService.new(user: current_user, exhibitor_kit: @exhibitor_kit)
    result = service.call

    if result.success?
      success_response(data: result.data, message: 'Order submitted successfully', status: :created)
    else
      error_response(message: 'Failed to submit order', errors: Array(result.errors), status: result.status)
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

  def format_exhibitor_kit(kit)
    kit.as_json(
      include: [
        { custom_requests: { only: [:id, :description, :quantity, :status, :resolved_price, :response_notes] } }
      ]
    ).merge(
      exhibitor_kit_items: kit.exhibitor_kit_items.map { |item| format_kit_item(item) },
      exhibitor_kit_printings: kit.exhibitor_kit_printings.map { |printing| format_kit_printing(printing) }
    )
  end

  def format_kit_item(item)
    item.as_json.merge(
      rentable_item: item.rentable_item ? format_rentable_item(item.rentable_item) : nil
    )
  end

  def format_kit_printing(printing)
    printing.as_json.merge(
      printing_service: printing.printing_service ? format_printing_service(printing.printing_service) : nil
    )
  end

  def format_rentable_item(item)
    item.as_json.merge(
      image_url: item.image.attached? ? url_for(item.image) : nil
    )
  end

  def format_printing_service(service)
    service.as_json.merge(
      image_url: service.image.attached? ? url_for(service.image) : nil
    )
  end
end