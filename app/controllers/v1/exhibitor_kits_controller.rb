class V1::ExhibitorKitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event
  before_action :set_exhibitor_kit, only: %i[show update destroy submit_order reject_payment_proof ic_copy permanently_delete force_delete]
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
      render json: format_exhibitor_kit(result.data), status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def update
    service = ExhibitorKitService.new(user: current_user, event: @event, params: params)
    result = service.update(@exhibitor_kit)

    if result.success?
      render json: format_exhibitor_kit(result.data), status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def destroy
    authorize @exhibitor_kit

    @exhibitor_kit.with_lock do
      payment = @exhibitor_kit.exhibitor_registration_payment
      payment&.lock!
      unless @exhibitor_kit.unpaid? && @exhibitor_kit.booking_active?
        return render json: { error: 'Only unpaid active exhibitor kits can be cancelled' },
                      status: :unprocessable_content
      end
      if payment&.gateway_order_id.present? && payment.order_expires_at&.future?
        return render json: { error: 'Exhibitor kit has an active payment order' },
                      status: :unprocessable_content
      end

      @exhibitor_kit.update!(booking_status: :cancelled)
    end

    head :no_content
  end

  def permanently_delete
    authorize @exhibitor_kit, :destroy?

    unless @exhibitor_kit.booking_cancelled?
      return render json: { error: 'Only cancelled exhibitor kits can be permanently deleted' },
                    status: :unprocessable_content
    end

    @exhibitor_kit.destroy!
    head :no_content
  end

  # Org-owner-only: hard-deletes a kit in any state, bypassing the cancel-first requirement
  # that #permanently_delete enforces for organizers.
  def force_delete
    authorize @exhibitor_kit, :force_destroy?

    @exhibitor_kit.destroy!
    head :no_content
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

  def reject_payment_proof
    authorize @exhibitor_kit, :update?
    payment = @exhibitor_kit.exhibitor_registration_payment
    return render json: { error: 'No payment proof submitted' }, status: :unprocessable_content unless payment&.payment_proof&.attached?

    payment.update!(status: 'rejected', note: params[:note].to_s.strip.presence)
    render json: format_exhibitor_kit(@exhibitor_kit.reload), status: :ok
  end

  def ic_copy
    authorize @exhibitor_kit, :download_ic_copy?
    return render json: { error: 'IC copy not found' }, status: :not_found unless @exhibitor_kit.ic_copy.attached?

    send_data @exhibitor_kit.ic_copy.download,
              filename: @exhibitor_kit.ic_copy.filename.to_s,
              type: @exhibitor_kit.ic_copy.content_type,
              disposition: 'attachment'
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_exhibitor_kit
    @exhibitor_kit = ExhibitorKit.joins(:event_vendor).find_by!(id: params[:id], event_vendors: { event_id: @event.id })
  end

  def ensure_event_has_exhibitor_kit_enabled
    return if @event.use_exhibitor_kit?

    render json: { error: 'Exhibitor kits are not enabled for this event' }, status: :forbidden
  end

  def format_exhibitor_kit(kit)
    # Filter items and printings for contractors
    items = kit.exhibitor_kit_items
    printings = kit.exhibitor_kit_printings

    if current_user.is_exhibition_contractor?
      # Contractors only see items where rentable_item belongs to them
      items = items.select { |item| item.rentable_item&.user_id == current_user.id }
      # Contractors only see printings if event allows contractor printing services and printing service belongs to them
      printings = if @event.allow_contractor_printing_services?
                    printings.select { |printing| printing.printing_service&.user_id == current_user.id }
                  else
                    []
                  end
    end

    kit.as_json(
      include: [
        { custom_requests: { only: %i[id description quantity status resolved_price response_notes] } }
      ]
    ).merge(
      ic_copy_uploaded: kit.ic_copy.attached?,
      payment_proof_url: kit.exhibitor_registration_payment&.payment_proof&.attached? ? url_for(kit.exhibitor_registration_payment.payment_proof) : nil,
      payment_proof_status: kit.exhibitor_registration_payment&.status || 'pending',
      payment_note: kit.exhibitor_registration_payment&.note || kit.payment_note,
      exhibitor_booth_price_label: kit.exhibitor_booth_price&.label,
      exhibitor_booth_price_zone: kit.exhibitor_booth_price&.zone,
      exhibitor_package_id: kit.exhibitor_package_id,
      exhibitor_package_name: kit.exhibitor_package&.name,
      exhibitor_package_inclusions: kit.exhibitor_package&.inclusions,
      exhibitor_team_members: kit.exhibitor_team_members.as_json(
        only: %i[id exhibitor_kit_id full_name email phone attendee_type attendee_id created_at updated_at]
      ),
      exhibitor_kit_items: items.map { |item| format_kit_item(item) },
      exhibitor_kit_printings: printings.map { |printing| format_kit_printing(printing) }
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
