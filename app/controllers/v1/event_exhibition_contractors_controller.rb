class V1::EventExhibitionContractorsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def show
    @event_exhibition_contractor = @event.event_exhibition_contractor
    if @event_exhibition_contractor.present?
      authorize @event_exhibition_contractor
      render json: @event_exhibition_contractor, status: :ok
    else
      render json: { message: "No exhibition contractor assigned to this event" }, status: :ok
    end
  end

  def create
    service = EventExhibitionContractorService.new(user: current_user, event: @event, params: params)
    result = service.create

    if result.success?
      render json: result.data, status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def destroy
    @event_exhibition_contractor = @event.event_exhibition_contractor
    if @event_exhibition_contractor.present?
      authorize @event_exhibition_contractor
      @event.update(use_exhibitor_kit: false)
      @event_exhibition_contractor.destroy
      head :no_content
    else
      render json: { error: 'Not Found', message: 'Event exhibition contractor not found.' }, status: :not_found
    end
  end

  private

  def set_event
    @event = Event.with_deleted.friendly.find(params[:event_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
  end
end
