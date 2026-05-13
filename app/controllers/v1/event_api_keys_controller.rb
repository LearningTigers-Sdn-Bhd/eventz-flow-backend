module V1
  class EventApiKeysController < ApplicationController
    before_action :set_event
    before_action :set_api_key, only: [:destroy]

    # GET /v1/events/:event_id/api_keys
    def index
      authorize @event, :update? # Only event admins/organizers can manage keys

      @api_keys = @event.api_keys.active
      render json: @api_keys.as_json(only: [:id, :name, :is_active, :last_used_at, :created_at, :event_id]), status: :ok
    end

    # POST /v1/events/:event_id/api_keys
    def create
      authorize @event, :update?

      unless @event.use_api_access?
        return render json: { error: 'API access is not enabled for this event.' }, status: :unprocessable_content
      end

      @api_key = current_user.api_keys.build(name: params[:name], event: @event)

      if @api_key.save
        render json: {
          id: @api_key.id,
          name: @api_key.name,
          is_active: @api_key.is_active,
          event_id: @api_key.event_id,
          raw_key: @api_key.raw_key,
          message: "API Key created. SAVE THIS KEY, it will not be shown again."
        }, status: :created
      else
        render json: { errors: @api_key.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/api_keys/:id
    def destroy
      authorize @event, :update?

      if @api_key.revoke!
        head :no_content
      else
        render json: { error: 'Failed to revoke key.' }, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Event not found' }, status: :not_found
    end

    def set_api_key
      @api_key = @event.api_keys.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found' }, status: :not_found
    end
  end
end
