class V1::EventExhibitionContractorsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  # GET /v1/events/:event_id/event_exhibition_contractor
  def show
    # Policy authorization will be added here
    # authorize @event, :show? # Assuming event show policy covers this
    
    event_exhibition_contractor = @event.event_exhibition_contractor
    if event_exhibition_contractor.present?
      render json: event_exhibition_contractor, status: :ok
    else
      render json: { message: "No exhibition contractor assigned to this event" }, status: :ok
    end
  end

  # POST /v1/events/:event_id/event_exhibition_contractor
  def create
    # Policy authorization will be added here
    # authorize EventExhibitionContractor

    @event_exhibition_contractor = EventExhibitionContractor.new(event_exhibition_contractor_params.merge(event: @event))

    if @event_exhibition_contractor.save
      render json: @event_exhibition_contractor, status: :created
    else
      render json: { errors: @event_exhibition_contractor.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /v1/events/:event_id/event_exhibition_contractor
  def destroy
    # Policy authorization will be added here
    # authorize @event_exhibition_contractor

    event_exhibition_contractor = @event.event_exhibition_contractor # Find the singular resource
    if event_exhibition_contractor.present?
      event_exhibition_contractor.destroy
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

  def event_exhibition_contractor_params
    params.require(:event_exhibition_contractor).permit(:exhibition_contractor_profile_id)
  end
end
