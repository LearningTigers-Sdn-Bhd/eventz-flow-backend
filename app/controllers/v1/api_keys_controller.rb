module V1
  class ApiKeysController < ApplicationController

    before_action :set_api_key, only: [:destroy]

    # GET /v1/api_keys
    def index
      @api_keys = policy_scope(ApiKey)
      authorize ApiKey

      render json: @api_keys.as_json(only: [:id, :name, :scope, :is_active, :last_used_at, :created_at, :event_id]), status: :ok
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    # POST /v1/api_keys
    def create
      # Only org_owner can elevate scope; organizers/members always get read_only.
      requested_scope = params[:scope].to_s.presence_in(ApiKey::SCOPES)
      scope = if current_user.is_org_owner? && requested_scope
                requested_scope
              else
                'read_only'
              end

      @api_key = current_user.api_keys.build(api_key_params.merge(scope: scope))
      authorize @api_key

      # Validate event allows API access if event_id provided
      if @api_key.event_id.present?
        event = Event.find_by(id: @api_key.event_id)
        unless event&.use_api_access?
          return render json: { error: 'API access is not enabled for this event.' }, status: :unprocessable_content
        end
      end

      if @api_key.save
        render json: {
          id: @api_key.id,
          name: @api_key.name,
          scope: @api_key.scope,
          is_active: @api_key.is_active,
          event_id: @api_key.event_id,
          raw_key: @api_key.raw_key,
          message: "API Key created (#{@api_key.scope}). SAVE THIS KEY, it will not be shown again."
        }, status: :created
      else
        render json: { errors: @api_key.errors.full_messages }, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    # DELETE /v1/api_keys/:id
    def destroy
      authorize @api_key

      if @api_key.revoke!
        head :no_content
      else
        render json: { error: 'Failed to revoke key.' }, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    private

    def set_api_key
      @api_key = current_user.api_keys.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found' }, status: :not_found
    end

    def api_key_params
      params.permit(:name, :event_id)
    end
  end
end
